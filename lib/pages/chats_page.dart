import 'package:driversapp2/pages/chat_page.dart';
import 'package:driversapp2/services/chat/chat_service.dart';
import 'package:driversapp2/widgets/user_tile.dart';
import 'package:flutter/material.dart';

class ChatsPage extends StatelessWidget {
ChatsPage({super.key});

  final ChatService _chatService = ChatService();

  @override
  Widget build (BuildContext context)
  {
    return Scaffold(
      appBar: AppBar(
      title: Text("Chats"),
    ),
    body: _buildUserList(),
    );
    
  }

  Widget _buildUserList()
  {
    return StreamBuilder(
  stream: _chatService.getUsersStream(), 
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Text ("Error");
      }
        if (snapshot.connectionState == ConnectionState.waiting)
        {
          return const Text("Loading...");
        }

        return ListView
        (
          children: snapshot.data!.map<Widget>((userData) => _buildUserListItem(userData , context))
          .toList(),
        );
    }
    );
  }

  //Despliega individualmente el usuario
  Widget _buildUserListItem
  (
    Map<String, dynamic> userData, BuildContext context)
    {
      //Despliega todos los usuarios excepto el usuario loggeado
      return UserTile(
        text: userData["email"],
        onTap:() {
          //Al hacer click en un usuario -> Ir a la pagina de chat
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => ChatPage(
              receiverEmail: userData["email"],
              ),
            ),
            );
            },
            );
        }   
    }
  


