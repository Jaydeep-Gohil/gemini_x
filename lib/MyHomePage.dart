import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gemini_x/message.dart';
import 'package:gemini_x/themeNotifier.dart';

class Myhomepage extends ConsumerStatefulWidget {
  const Myhomepage({super.key});

  @override
  ConsumerState<Myhomepage> createState() => _MyhomepageState();
}

class _MyhomepageState extends ConsumerState<Myhomepage> {
  TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [
    Message(text: "Hii", isUser: true),
    Message(text: "How are You", isUser: false),
    Message(text: "I am fine", isUser: true),
    Message(text: "Grate", isUser: false),
  ];

  ThemeMode currentTheme = ThemeMode.light;

  @override
  void initState() {
    getCurrentTheme();
    super.initState();
  }
  getCurrentTheme(){
    final currentTheme = ref.read(themeProvider);
  }

  @override
  Widget build(BuildContext context) {
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
                Image.asset('assets/gpt-robot.png'),
                SizedBox(width: 10,),
                Text('Gemini X',style: Theme.of(context).textTheme.titleLarge)
              ],
            ),
            GestureDetector(
              onTap: (){
                ref.read(themeProvider.notifier).toggleTheme();
              },
                child: (currentTheme ==ThemeMode.dark)?Icon(Icons.light_mode):Icon(Icons.dark_mode),
            ),
          ],
        ),

      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
                itemCount: _messages.length ,
                itemBuilder: (context,index){
              final message = _messages[index];
              return ListTile(
                title: Align(
                  alignment: message.isUser?Alignment.centerRight:Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: message.isUser ? Theme.of(context).colorScheme.primary :Theme.of(context).colorScheme.secondary,
                      borderRadius:message.isUser ? BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ):BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      )
                    ),
                    child: Text(message.text,style: message.isUser ?
                    Theme.of(context).textTheme.bodyMedium :
                    Theme.of(context).textTheme.bodySmall),
                  ),
                ),
              );
            }),
          ),

          //user input
          Padding(
            padding: const EdgeInsets.only(bottom: 30,left: 16,top: 16,right: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  )
                ]
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: Theme.of(context).textTheme.titleSmall,
                      decoration: InputDecoration(
                        hintText: "Write Your message",
                        hintStyle: Theme.of(context).textTheme.titleSmall!.copyWith(
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                  SizedBox(width: 8,),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GestureDetector(
                      onTap:(){

                      },
                      child: Image.asset('assets/send.png'),

                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      )
    );
  }
}
