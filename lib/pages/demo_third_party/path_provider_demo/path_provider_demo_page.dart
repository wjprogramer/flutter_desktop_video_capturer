import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/third_party/open_file/open_file.dart';
import 'package:flutter_desktop_video_capturer/third_party/path_provider/path_provider.dart';

class PathProviderDemoPage extends StatelessWidget {
  const PathProviderDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Path Provider Demo'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('getAppDocsDir'),
            onTap: () async {
              final dir = await MyPathProvider.getAppDocsDir();
              MyOpenFile.open(dir.path);
            },
          ),
          ListTile(
            title: const Text('getAppDir'),
            onTap: () async {
              final dir = await MyPathProvider.getAppDir();
              MyOpenFile.open(dir.path);
            },
          ),
        ],
      ),
    );
  }
}
