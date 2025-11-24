// lib/Myhomepage.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message.dart';
import 'themeNotifier.dart';

class Myhomepage extends ConsumerStatefulWidget {
  const Myhomepage({super.key});

  @override
  ConsumerState<Myhomepage> createState() => _MyhomepageState();
}

class _MyhomepageState extends ConsumerState<Myhomepage> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [
  ];

  bool isLoading = false;
  String? _lastPrompt; // used for retry
  static const _storageKey = 'chat_messages_v1';

  @override
  void initState() {
    super.initState();
    _loadMessagesLocally();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // shared_preferences

  Map<String, dynamic> _messageToMap(Message m) => {
    'text': m.text,
    'isUser': m.isUser,
  };

  Message _messageFromMap(Map<String, dynamic> map) {
    return Message(text: map['text'] ?? '', isUser: map['isUser'] ?? false);
  }

  Future<void> _saveMessagesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _messages.map((m) => jsonEncode(_messageToMap(m))).toList();
      await prefs.setStringList(_storageKey, list);
    } catch (e) {
      debugPrint('saveMessages error: $e');
    }
  }

  Future<void> _loadMessagesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];
      final loaded = list.map((s) {
        try {
          final map = jsonDecode(s) as Map<String, dynamic>;
          return _messageFromMap(map);
        } catch (_) {
          return Message(text: s, isUser: false);
        }
      }).toList();

      if (loaded.isNotEmpty) {
        setState(() {
          _messages.clear();
          // keep newest first (we display reversed list)
          _messages.addAll(loaded.reversed);
        });
      }
    } catch (e) {
      debugPrint('loadMessages error: $e');
    }
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    setState(() {
      _messages.clear();
    });
  }


  // Clipboard

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }


  // Gemini call
  Future<void> callGeminiModel({String? promptOverride}) async {
    final prompt = (promptOverride ?? _controller.text).trim();
    if (prompt.isEmpty) return;

    // mark last prompt (for retry)
    _lastPrompt = prompt;

    // show user's message immediately
    setState(() {
      _messages.insert(0, Message(text: prompt, isUser: true));
      isLoading = true;
    });
    await _saveMessagesLocally();

    final apiKey = dotenv.env['GOOGLE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _showAndInsert('API key missing (dev only).');
      setState(() => isLoading = false);
      return;
    }

    final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);

    const int maxAttempts = 4;
    int attempt = 0;
    int baseDelayMs = 800;
    final rng = Random();

    while (attempt < maxAttempts) {
      attempt++;
      debugPrint('DBG retry attempt #$attempt');

      try {
        final GenerateContentResponse response = await model
            .generateContent([Content.text(prompt)])
            .timeout(const Duration(seconds: 50));

        final botText = _extractTextFromGenerateResponse(response);
        setState(() {
          _messages.insert(0, Message(text: botText, isUser: false));
          _lastPrompt = null; // success -> clear lastPrompt
        });
        await _saveMessagesLocally();
        _controller.clear();
        break;
      } on TimeoutException {
        debugPrint('DBG: timeout attempt $attempt');
        if (attempt >= maxAttempts) {
          _showAndInsert('Request timed out after multiple attempts.');
        } else {
          final jitter = rng.nextInt(500);
          await Future.delayed(Duration(milliseconds: baseDelayMs + jitter));
          baseDelayMs *= 2;
          continue;
        }
      } on GenerativeAIException catch (g) {
        final msg = g.toString();
        debugPrint('DBG GenerativeAIException: $msg');

        if (msg.contains('503') || msg.contains('UNAVAILABLE') || msg.toLowerCase().contains('overloaded')) {
          if (attempt < maxAttempts) {
            final jitter = rng.nextInt(500);
            await Future.delayed(Duration(milliseconds: baseDelayMs + jitter));
            baseDelayMs *= 2;
            continue;
          } else {
            _showAndInsert('Model is busy. Please try again later.');
          }
        } else {
          _showAndInsert('Server error: ${_shorten(g.message ?? g.toString())}');
        }
        break;
      } catch (e, st) {
        debugPrint('DBG unexpected error: $e\n$st');
        final emsg = e.toString();
        if (emsg.contains('Failed host lookup') || emsg.contains('SocketException')) {
          _showAndInsert('Network error: check your internet connection.');
        } else {
          _showAndInsert('Error: ${_shorten(emsg)}');
        }
        break;
      } finally {
        if (attempt >= maxAttempts) {
          setState(() => isLoading = false);
        }
      }
    }

    setState(() => isLoading = false);
  }

  // Extract text safely from typed response
  String _extractTextFromGenerateResponse(GenerateContentResponse response) {
    try {
      if (response.candidates.isNotEmpty) {
        final Candidate first = response.candidates.first;
        if (first.text != null && first.text!.trim().isNotEmpty) return first.text!;

        final content = first.content;
        if (content != null && content.parts != null && content.parts!.isNotEmpty) {
          final buffer = StringBuffer();
          for (final Part p in content.parts!) {
            if (p is TextPart) buffer.write(p.text);
            // ignore other part types for now
          }
          final collected = buffer.toString().trim();
          if (collected.isNotEmpty) return collected;
        }
        return first.toString();
      }

      if (response.functionCalls.isNotEmpty) {
        return 'Model returned a function call: ${response.functionCalls.first.toString()}';
      }

      return 'No reply from model';
    } catch (e) {
      debugPrint('extractText error: $e');
      return 'Error extracting text';
    }
  }

  // UI helpers
  void _showAndInsert(String text) {
    setState(() {
      _messages.insert(0, Message(text: text, isUser: false));
    });
    _saveMessagesLocally();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _shorten(String s, [int max = 160]) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 1,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Image.asset('assets/gpt-robot.png', height: 32),
                const SizedBox(width: 10),
                Text('Gemini X', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_forever_outlined),
                  tooltip: 'Clear chat',
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Clear chat?'),
                        content: (currentTheme == ThemeMode.dark) ?
                        Text('Are you sure you want to delete the chat history?',style:Theme.of(context).textTheme.titleMedium,):
                        Text('Are you sure you want to delete the chat history?',style:Theme.of(context).textTheme.titleMedium,),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (ok == true) _clearHistory();
                  },
                ),
                GestureDetector(
                  onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                  child: (currentTheme == ThemeMode.dark) ? const Icon(Icons.light_mode) : const Icon(Icons.dark_mode),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                child:
                Text('Say hi to the bot!',))
                : ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
                final bubbleColor = message.isUser ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;
                final textStyle = message.isUser ? Theme.of(context).textTheme.bodyMedium : Theme.of(context).textTheme.bodySmall;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Align(
                    alignment: alignment,
                    child: InkWell(
                      onLongPress: () => _copyToClipboard(message.text),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(16)),
                        child: Text(message.text, style: textStyle),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (isLoading) const LinearProgressIndicator(),

          // input area with retry button
          Padding(
            padding: const EdgeInsets.only(bottom: 30, left: 16, top: 16, right: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black12,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.25), spreadRadius: 3, blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  // Retry button (visible when last prompt exists)
                  if (_lastPrompt != null)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Retry last message',
                      onPressed: isLoading ? null : () => callGeminiModel(promptOverride: _lastPrompt),
                    )
                  else
                    const SizedBox(width: 8),

                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: Theme.of(context).textTheme.titleSmall,
                      decoration: InputDecoration(
                        hintText: "Write Your message",
                        hintStyle: Theme.of(context).textTheme.titleSmall!.copyWith(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!isLoading) callGeminiModel();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: GestureDetector(
                      onTap: isLoading ? null : () => callGeminiModel(),
                      child: Image.asset('assets/send.png', height: 28),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
