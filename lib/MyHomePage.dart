import 'package:flutter/material.dart';
import 'package:gemini_x/message.dart';

class Myhomepage extends StatefulWidget {
  const Myhomepage({super.key});

  @override
  State<Myhomepage> createState() => _MyhomepageState();
}

class _MyhomepageState extends State<Myhomepage> {
  TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [
    Message(text: "Hii", isUser: true),
    Message(text: "How are You", isUser: false),
    Message(text: "I am fine", isUser: true),
    Message(text: "Grate", isUser: false),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Image.asset('assets/gpt-robot.png'),
                SizedBox(width: 10,),
                Text('Gemini X',style: TextStyle(color: Colors.black),)
              ],
            ),
            Image.asset('assets/volume-high.png',color: Colors.blue[800],),
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
                      color: message.isUser ? Colors.blue : Colors.grey[300],
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
                    child: Text(message.text,style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black,
                    ),),
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
                      decoration: InputDecoration(
                        hintText: "Type a message",
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
