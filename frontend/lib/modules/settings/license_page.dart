import 'package:flutter/material.dart';
import 'package:xiaojia_ledger/core/theme.dart';

class LicensePage extends StatelessWidget {
  const LicensePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('开源许可', style: TextStyle(color: AppColors.ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          // MIT License
          PremiumCard(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MIT 许可证',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'MIT License',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Copyright (c) 2026 小满记账团队',
                  style: TextStyle(fontSize: 12, color: AppColors.gray),
                ),
                SizedBox(height: 12),
                Text(
                  'Permission is hereby granted, free of charge, to any person obtaining a copy '
                  'of this software and associated documentation files (the "Software"), to deal '
                  'in the Software without restriction, including without limitation the rights '
                  'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
                  'copies of the Software, and to permit persons to whom the Software is '
                  'furnished to do so, subject to the following conditions:\n\n'
                  'The above copyright notice and this permission notice shall be included in all '
                  'copies or substantial portions of the Software.\n\n'
                  'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR '
                  'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, '
                  'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE '
                  'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER '
                  'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, '
                  'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.ink,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // 第三方库
          PremiumCard(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第三方库',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 12),
                _libRow('Flutter', 'Google', 'BSD-3-Clause'),
                _libRow('Dart', 'Google', 'BSD-3-Clause'),
                _libRow('FastAPI', 'Encode OSS', 'MIT'),
                _libRow('SQLAlchemy', 'Mike Bayer', 'MIT'),
                _libRow('fl_chart', 'FlChart', 'MIT'),
                _libRow('shared_preferences', 'Flutter', 'BSD-3-Clause'),
                _libRow('flutter_local_notifications', 'Flutter', 'MIT'),
                _libRow('permission_handler', 'Baseflow', 'MIT'),
                _libRow('DeepSeek', 'DeepSeek', 'Proprietary'),
                _libRow('通义千问', '阿里巴巴', 'Proprietary'),
              ],
            ),
          ),
          SizedBox(height: 16),

          // 许可证链接
          Center(
            child: Text(
              '完整许可证文本请查看',
              style: TextStyle(fontSize: 12, color: AppColors.gray),
            ),
          ),
          Center(
            child: Text(
              'https://opensource.org/licenses/MIT',
              style: TextStyle(fontSize: 12, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _libRow(String name, String author, String license) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 14, color: AppColors.ink),
            ),
          ),
          Expanded(
            child: Text(
              author,
              style: TextStyle(fontSize: 14, color: AppColors.gray),
            ),
          ),
          Expanded(
            child: Text(
              license,
              style: TextStyle(fontSize: 14, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
