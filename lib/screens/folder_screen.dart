import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FolderScreen extends StatelessWidget {
  const FolderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Folder', style: GoogleFonts.poppins()),
      ),
      body: const Center(child: Text('Folder screen')),
    );
  }
}