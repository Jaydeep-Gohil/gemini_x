import 'dart:async'; // for TimeoutException
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gemini_x/message.dart';
import 'package:gemini_x/themeNotifier.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  void _copyToClipboard(String text){
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }



  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  // 1) list models — verifies key + network
  Future<void> listGeminiModels() async {
    final apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
    debugPrint('DBG listModels: apiKeyPresent=${apiKey.isNotEmpty}');
    final url = Uri.parse('https://api.generative.ai/v1/models');

    try {
      final resp = await http.get(url, headers: {
        'x-goog-api-key': apiKey,
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 15));

      debugPrint('DBG listModels: status=${resp.statusCode}');
      debugPrint('DBG listModels: body=${resp.body}');
    } catch (e, st) {
      debugPrint('DBG listModels exception: $e\n$st');
    }
  }

// 2) simple generate test using REST — shows raw response fast
  Future<void> simpleGenerateTest() async {
    final apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
    final url = Uri.parse('https://api.generative.ai/v1/models/gemini-2.5-pro:generate');
    final body = {
      'input': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Say hello in one line.'}
          ]
        }
      ]
    };

    try {
      final resp = await http.post(url,
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));

      debugPrint('DBG gen: status=${resp.statusCode}');
      debugPrint('DBG gen: body=${resp.body}');
    } catch (e, st) {
      debugPrint('DBG gen exception: $e\n$st');
    }
  }

  Future<void> callGeminiModel() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    // Show user message immediately
    setState(() {
      _messages.insert(0, Message(text: prompt, isUser: true));
      isLoading = true;
    });

    final apiKey = dotenv.env['GOOGLE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _showAndInsert('API key missing (dev only).');
      setState(() => isLoading = false);
      return;
    }

    final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);

    const int maxAttempts = 5;
    int attempt = 0;
    int baseDelayMs = 1000; // 1s
    final rng = Random();

    while (attempt < maxAttempts) {
      attempt++;
      debugPrint('DBG retry: attempt #$attempt');

      try {
        // Increase timeout to allow slower responses
        final GenerateContentResponse response =
        await model.generateContent([Content.text(prompt)]).timeout(const Duration(seconds: 60));

        debugPrint('DBG: SDK success candidates=${response.candidates.length}');
        final botText = _extractTextFromGenerateResponse(response);

        setState(() => _messages.insert(0, Message(text: botText, isUser: false)));
        _controller.clear();
        break; // success
      } on TimeoutException {
        debugPrint('DBG: SDK timeout on attempt $attempt');
        if (attempt >= maxAttempts) {
          _showAndInsert('Request timed out after multiple attempts.');
        } else {
          final jitter = rng.nextInt(500);
          final wait = baseDelayMs + jitter;
          debugPrint('DBG: waiting ${wait}ms before retry');
          await Future.delayed(Duration(milliseconds: wait));
          baseDelayMs *= 2; 
          continue;
        }
      } on GenerativeAIException catch (g) {
        final msg = g.toString();
        debugPrint('DBG: GenerativeAIException: $msg');

    
        if (msg.contains('503') || msg.contains('UNAVAILABLE') || msg.toLowerCase().contains('overloaded')) {
          if (attempt < maxAttempts) {
            final jitter = rng.nextInt(500);
            final wait = baseDelayMs + jitter;
            debugPrint('DBG: model overloaded, retrying after ${wait}ms');
            await Future.delayed(Duration(milliseconds: wait));
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
        // Generic catch (works on Web + mobile)
        debugPrint('DBG: unexpected exception: $e\n$st');
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

// helper to insert message and show snack
  void _showAndInsert(String text) {
    setState(() {
      _messages.insert(0, Message(text: text, isUser: false));
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

// shortens long error messages for UI
  String _shorten(String s, [int max = 140]) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }


  String _extractTextFromGenerateResponse(GenerateContentResponse response) {
    try {
      // Prefer typed candidates
      if (response.candidates.isNotEmpty) {
        final Candidate first = response.candidates.first;

        if (first.text != null && first.text!.trim().isNotEmpty) {
          return first.text!;
        }

        
        final content = first.content;
        if (content != null && content.parts != null && content.parts!.isNotEmpty) {
          final parts = content.parts!;
          final buffer = StringBuffer();

          for (final Part p in parts) {
            if (p is TextPart) {
              // safe to access .text because p is TextPart
              buffer.write(p.text);
            }
            // optionally handle other Part subtypes here (BlobPart, InlineDataPart, etc.)
          }

          final collected = buffer.toString().trim();
          if (collected.isNotEmpty) return collected;
        }

        // Last resort: toString()
        return first.toString();
      }

      // If the model returned a function call or something else
      if (response.functionCalls.isNotEmpty) {
        return 'Model returned a function call: ${response.functionCalls.first.toString()}';
      }

      return 'No reply from model';
    } catch (e) {
      debugPrint('extractText fallback error: $e');
      return 'Error extracting text';
    }
  }


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
            GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
              child: (currentTheme == ThemeMode.dark) ? const Icon(Icons.light_mode) : const Icon(Icons.dark_mode),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Say hi to the bot!'))
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
                    padding: const EdgeInsets.all(16.0),
                    child: GestureDetector(
                      onTap: isLoading ? null : callGeminiModel,
                      child: Image.asset('assets/send.png', height: 28),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
