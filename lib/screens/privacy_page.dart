import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('개인정보처리방침'),
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
                  Text('🔒', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text(
                    '개인정보처리방침',
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

            // 1. 개인정보 수집·이용 목적
            _buildSection(
              '1. 개인정보 수집·이용 목적',
              '공무원맛집은 다음의 목적을 위하여 개인정보를 처리합니다:',
              bulletPoints: [
                '회원 식별 및 서비스 제공',
                '알림 서비스 제공',
                '서비스 개선 및 통계 분석',
              ],
            ),

            // 2. 수집하는 개인정보 항목
            _buildSection(
              '2. 수집하는 개인정보 항목',
              '공무원맛집은 최소한의 개인정보만을 수집합니다:',
              customContent: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('필수항목: 이메일 주소, 닉네임',
                      style: TextStyle(color: Colors.black87, height: 1.6)),
                  SizedBox(height: 8),
                  Text('선택항목: 위치정보 제공 동의',
                      style: TextStyle(color: Colors.black87, height: 1.6)),
                ],
              ),
            ),

            // 3. 개인정보의 보유 및 이용기간
            _buildSection(
              '3. 개인정보의 보유 및 이용기간',
              '회원탈퇴 시 즉시 삭제되며, 관련 법령에 의해 보존이 필요한 경우를 제외하고는 개인정보를 보유하지 않습니다.',
            ),

            // 4. 개인정보의 제3자 제공
            _buildSection(
              '4. 개인정보의 제3자 제공',
              '공무원맛집은 원칙적으로 이용자의 개인정보를 외부에 제공하지 않습니다. 다만, 다음의 경우에는 예외로 합니다:',
              bulletPoints: [
                '이용자들이 사전에 동의한 경우',
                '법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우',
              ],
            ),

            // 5. 개인정보 처리의 위탁
            _buildSection(
              '5. 개인정보 처리의 위탁',
              '공무원맛집은 서비스 제공을 위해 다음과 같이 개인정보 처리업무를 위탁하고 있습니다:',
              customContent: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Supabase: 회원정보 관리 및 인증',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ),

            // 6. 개인정보의 안전성 확보조치
            _buildSection(
              '6. 개인정보의 안전성 확보조치',
              '공무원맛집은 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다:',
              bulletPoints: [
                '관리적 조치: 개인정보 취급 직원의 최소화 및 교육',
                '기술적 조치: 개인정보처리시스템 등의 접근권한 관리, 접근통제시스템 설치, 고유식별정보 등의 암호화, 보안프로그램 설치',
                '물리적 조치: 전산실, 자료보관실 등의 접근통제',
              ],
            ),

            // 7. 개인정보 보호책임자
            _buildSection(
              '7. 개인정보 보호책임자',
              '공무원맛집은 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와 관련한 정보주체의 불만처리 및 피해구제 등을 위하여 아래와 같이 개인정보 보호책임자를 지정하고 있습니다:',
              customContent: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('개인정보 보호책임자',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('연락처: thenaum2030@naver.com'),
                    SizedBox(height: 8),
                    Text(
                      '※ 개인정보 보호 관련 문의사항이 있으시면 위 연락처로 연락해 주시기 바랍니다.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // 8. 정보주체의 권리·의무 및 그 행사방법
            _buildSection(
              '8. 정보주체의 권리·의무 및 그 행사방법',
              '이용자는 개인정보주체로서 다음과 같은 권리를 행사할 수 있습니다:',
              bulletPoints: [
                '개인정보 처리현황 통지요구',
                '개인정보 처리정지 요구',
                '개인정보의 정정·삭제 요구',
                '손해배상 청구',
              ],
              additionalText:
                  '위의 권리 행사는 개인정보 보호법 시행령 제41조제1항에 따라 서면, 전자우편, 모사전송(FAX) 등을 통하여 하실 수 있으며 공무원맛집은 이에 대해 지체 없이 조치하겠습니다.',
            ),

            // 9. 개인정보의 파기
            _buildSection(
              '9. 개인정보의 파기',
              '공무원맛집은 원칙적으로 개인정보 처리목적이 달성된 경우에는 지체없이 해당 개인정보를 파기합니다.',
              customContent: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text(
                    '파기절차: 이용자가 입력한 정보는 목적 달성 후 별도의 DB에 옮겨져(종이의 경우 별도의 서류) 내부 방침 및 기타 관련 법령에 따라 일정기간 저장된 후 혹은 즉시 파기됩니다.',
                    style: TextStyle(color: Colors.black87, height: 1.6),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '파기방법: 전자적 파일 형태의 정보는 기록을 재생할 수 없는 기술적 방법을 사용합니다.',
                    style: TextStyle(color: Colors.black87, height: 1.6),
                  ),
                ],
              ),
            ),

            // 10. 개인정보 처리방침 변경
            _buildSection(
              '10. 개인정보 처리방침 변경',
              '이 개인정보처리방침은 시행일로부터 적용되며, 법령 및 방침에 따른 변경내용의 추가, 삭제 및 정정이 있는 경우에는 변경사항의 시행 7일 전부터 공지사항을 통하여 고지할 것입니다.',
            ),

            // 11. 개인정보의 열람청구
            _buildSection(
              '11. 개인정보의 열람청구',
              '정보주체는 개인정보 보호법 제35조에 따른 개인정보의 열람 청구를 아래의 부서에 할 수 있습니다.',
              customContent: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('개인정보 열람청구 접수·처리 부서',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('이메일: thenaum2030@naver.com'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 시행일
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: const Column(
                children: [
                  Text(
                    '본 개인정보처리방침은 2025년 8월 21일부터 시행됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '공무원맛집 | 개인정보 보호 문의: thenaum2030@naver.com',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
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
    List<String>? bulletPoints,
    Widget? customContent,
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
          if (bulletPoints != null) ...[
            const SizedBox(height: 8),
            ...bulletPoints.map((point) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.black87)),
                      Expanded(
                        child: Text(
                          point,
                          style:
                              const TextStyle(color: Colors.black87, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (customContent != null) ...[
            const SizedBox(height: 12),
            customContent,
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




