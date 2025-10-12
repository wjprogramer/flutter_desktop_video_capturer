import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/pages/combine_with_lyrics/combine_with_lyrics_demo.dart';

import '../detector_images_pitches/detector_images_pitches_page.dart';
import '../process_horizontal_images/process_horizontal_images_page.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_Item>[
      _Item(name: '組合、重新裁切圖片', page: (_) => PanoramaCutterPage()),
      _Item(name: '偵測圖片上的音階', page: (_) => DetectorImagesPitchesPage()),
      _Item(name: '結合歌詞與音階', page: (_) => CombineWithLyricsDemoPage()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Menu'),
      ),
      body: ListView.separated(
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            title: Text(item.name),
            onTap: item.page == null ? null : () {
              Navigator.of(context).push(MaterialPageRoute(builder: item.page!));
            },
          );
        },
        separatorBuilder: (context, index) => Divider(height: 1),
        itemCount: items.length,
      ),
    );
  }
}

class _Item {
  const _Item({
    required this.name,
    this.page,
  });

  final String name;
  final WidgetBuilder? page;
}
