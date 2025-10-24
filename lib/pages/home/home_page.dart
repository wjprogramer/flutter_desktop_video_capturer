import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/extensions/collection.dart';
import 'package:flutter_desktop_video_capturer/pages/combine_with_lyrics/combine_with_lyrics_demo.dart';
import 'package:flutter_desktop_video_capturer/pages/demo_third_party/path_provider_demo/path_provider_demo_page.dart';
import 'package:flutter_desktop_video_capturer/pages/detector_images_pitches/detector_images_pitches_page.dart';
import 'package:flutter_desktop_video_capturer/pages/main_feature/main_feature_page.dart';
import 'package:flutter_desktop_video_capturer/pages/process_horizontal_images/process_horizontal_images_page.dart';
import 'package:flutter_desktop_video_capturer/pages/video_capturer/page.dart';
import 'package:flutter_desktop_video_capturer/third_party/open_file/open_file.dart';
import 'package:flutter_desktop_video_capturer/third_party/path_provider/path_provider.dart';
import 'package:flutter_desktop_video_capturer/utilities/file_structure_utility.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = <_Group>[
      _Group(
        name: '主要功能',
        items: [_Item(name: '主要功能', page: (_) => MainFeaturePage())],
      ),
      _Group(
        name: '子功能',
        items: <_Item>[
          _Item(name: '擷取影片', page: (_) => CapturerPage()),
          _Item(name: '組合、重新裁切圖片', page: (_) => PanoramaCutterPage()),
          _Item(name: '偵測圖片上的音階', page: (_) => DetectorImagesPitchesPage()),
          _Item(name: '結合歌詞與音階', page: (_) => CombineWithLyricsDemoPage()),
        ],
      ),
      _Group(name: '工具', items: []),
      _Group(
        name: 'Third Party',
        items: [_Item(name: 'path_provider demo', page: (_) => PathProviderDemoPage())],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Menu')),
      body: ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, groupIndex) {
          final group = groups[groupIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(group.name, style: Theme.of(context).textTheme.titleLarge),
              ),
              ...group.items
                  .map<Widget>((item) {
                    return ListTile(
                      title: Text(item.name),
                      onTap: item.page == null
                          ? null
                          : () {
                              Navigator.of(context).push(MaterialPageRoute(builder: item.page!));
                            },
                    );
                  })
                  .joinWith(
                    Container(
                      decoration: BoxDecoration(border: Border(bottom: Divider.createBorderSide(context))),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Group {
  const _Group({required this.name, required this.items});

  final String name;
  final List<_Item> items;
}

class _Item {
  const _Item({required this.name, this.page});

  final String name;
  final WidgetBuilder? page;
}
