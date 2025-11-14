import 'package:flutter/material.dart';
import 'package:gemini_x/MyHomePage.dart';

class OnBoarding extends StatelessWidget {
  const OnBoarding({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Text("Your AI Assistent",style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold,color: Colors.blue),),
                SizedBox(height: 16,),
                Text("Using this Software, you can Ask Your Qustion and Receicve articals using Artificial Intelligence assistent.",
                  textAlign: TextAlign.center,
                  style: TextStyle(

                      fontSize: 16,
                      color: Colors.black54
                  ),
                ),
              ],
            ),
            SizedBox(height: 16,),
            Image.asset("assets/onboarding.png"),
            SizedBox(height: 32,),
            ElevatedButton(
                onPressed: (){
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context)=>Myhomepage()), (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:  BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16,horizontal: 32),
                ),


                child: Row(
                  mainAxisSize: MainAxisSize.min,
              children: [
                Text("Continue"),
                SizedBox(height: 16,),
                Icon(Icons.arrow_forward),
              ],
            ))

          ],
        ),
      ),
    );
  }
}
