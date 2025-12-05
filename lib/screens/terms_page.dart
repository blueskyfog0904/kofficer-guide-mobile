import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('서비스 이용약관'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            const Center(
              child: Column(
                children: [
                  Text('📋', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text(
                    '서비스 이용약관',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 제1조 (목적)
            _buildSection(
              '제1조 (목적)',
              '이 약관은 더나움마켓(이하 "회사")가 제공하는 서비스의 이용과 관련하여 회사와 회원 간의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.',
            ),

            // 제2조 (정의)
            _buildSection(
              '제2조 (정의)',
              '본 약관에서 사용하는 용어의 정의는 다음과 같습니다:',
              numberedPoints: [
                '"서비스"란 회사가 제공하는 공무원 맛집 정보 제공 서비스를 의미합니다.',
                '"회원"이란 서비스에 접속하여 이 약관에 따라 회사와 이용계약을 체결하고 회사가 제공하는 서비스를 이용하는 자를 의미합니다.',
              ],
            ),

            // 제3조 (서비스의 제공)
            _buildSection(
              '제3조 (서비스의 제공)',
              '회사는 다음과 같은 서비스를 제공합니다:',
              numberedPoints: [
                '업무추진비 기준 음식점 정보',
                '커뮤니티 게시판 서비스',
                '기타 회사가 정하는 서비스',
              ],
            ),

            // 제4조 (회원가입)
            _buildSection(
              '제4조 (회원가입)',
              '서비스 이용을 위해서는 소셜 로그인을 통한 회원가입이 필요하며, 본 약관에 동의한 자에 한하여 회원가입이 가능합니다.',
            ),

            // 제5조 (서비스 이용)
            _buildSection(
              '제5조 (서비스 이용)',
              '회원은 서비스를 건전하고 올바른 목적으로 이용해야 하며, 다음 행위를 하여서는 안 됩니다:',
              numberedPoints: [
                '타인의 정보 도용',
                '회사의 서비스 정보를 이용하여 얻은 정보를 회사의 사전 승낙 없이 복제, 송신, 출판, 배포, 방송 기타 방법에 의하여 영리목적으로 이용하거나 제3자에게 이용하게 하는 행위',
                '스팸성 광고 게시 및 욕설, 비방 등 부적절한 콘텐츠 게시',
              ],
            ),

            // 제6조 (금지행위 및 제재)
            _buildSection(
              '제6조 (금지행위 및 제재)',
              '회원은 다음과 같은 행위를 절대 해서는 안 되며, 회사는 이에 대해 무관용 정책을 적용합니다:',
              numberedPoints: [
                '음란물, 폭력적, 차별적, 혐오 표현이 포함된 콘텐츠 게시',
                '타인을 괴롭히거나 위협하는 행위',
                '허위정보 유포 및 스팸 게시',
                '기타 법령에 위반되거나 사회질서를 해치는 행위',
              ],
              additionalText: '위반 시 즉시 게시물 삭제, 계정 정지 또는 영구 제명 조치가 가능합니다.',
            ),

            // 제7조 (신고 및 모니터링)
            _buildSection(
              '제7조 (신고 및 모니터링)',
              '부적절한 콘텐츠 발견 시 즉시 신고할 수 있으며, 회사는 24시간 내 검토 후 조치합니다.',
            ),

            const SizedBox(height: 32),

            // 시행일
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: const Text(
                '본 약관은 2025년 8월 21일부터 시행됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    String description, {
    List<String>? numberedPoints,
    String? additionalText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Colors.black87,
              height: 1.6,
            ),
          ),
          if (numberedPoints != null) ...[
            const SizedBox(height: 8),
            ...numberedPoints.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${entry.key + 1}. ',
                          style: const TextStyle(color: Colors.black87)),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                              color: Colors.black87, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (additionalText != null) ...[
            const SizedBox(height: 12),
            Text(
              additionalText,
              style: const TextStyle(color: Colors.black87, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }
}



