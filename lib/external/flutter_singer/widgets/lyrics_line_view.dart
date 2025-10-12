import 'package:flutter/material.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer/models/models.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer/utilities/html_parser.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer/utilities/json.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer/widgets/gap.dart';
import 'package:flutter_desktop_video_capturer/external/flutter_singer/widgets/lyrics_text.dart';

class LyricsLineView extends StatelessWidget {
  const LyricsLineView({
    super.key,
    required this.line,
    this.isActive = false,
    this.debugMode = false,
    this.onPlay,
  });

  final LyricsLine line;

  final bool isActive;

  final bool debugMode;

  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPlay,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (debugMode) ...[
                      Text(FSJson.durationToText(line.startTime)),
                      const FSGap(16),
                    ],
                    Expanded(
                      child: LyricsText(
                        FSHtmlParser.parseHtml(line.content),
                        style: TextStyle(
                          color: isActive ? Colors.red : null,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (debugMode) ...[
                      Text(FSJson.durationToText(line.endTime)),
                      const FSGap(16),
                    ],
                    Expanded(
                      child: Text(line.translation['zh_tw'] ?? ''),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}
