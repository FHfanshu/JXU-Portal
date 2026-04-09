import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/features/campus_card/ecard_service.dart';

void main() {
  group('EcardService.md5Hash', () {
    test('computes correct MD5 hash', () {
      final result = EcardService.md5Hash('hello');
      expect(result, '5d41402abc4b2a76b9719d911017c592');
    });

    test('computes MD5 with pipe separator and secret key', () {
      final result = EcardService.md5Hash(
        '213544|20260409174434|ok15we1@oid8x5afd@',
      );
      expect(result, '32545e3364153de4107d5f149058e7e7');
    });

    test('computes MD5 for QR code info request', () {
      final qrCode =
          'AB4035960E1B59CC6C4AFEFD2E76C4DE7403FC5DE0B19C3FDEDE13A9C606F4A69DB97ADB104353CC7E84DA2ABC7696CAB747F464D8CB2E51EB8D3352E792F926D2ED025B9706A4FE770408207BD2170B1C310D63FA738C30,12066';
      final result = EcardService.md5Hash(
        '$qrCode|20260409174423|ok15we1@oid8x5afd@',
      );
      expect(result, '5a4f84ece9fc4b258fd5a8261910aec3');
    });
  });

  group('EcardService.generateSign', () {
    test('generates correct Sign for AccNum+Time', () {
      final sign = EcardService.generateSign(['213544', '20260409174434']);
      expect(sign, '32545e3364153de4107d5f149058e7e7');
    });

    test('generates correct Sign for IDNo+IDType+Time', () {
      final sign = EcardService.generateSign(['213544', '1', '20260409174434']);
      final expected = EcardService.md5Hash(
        '213544|1|20260409174434|ok15we1@oid8x5afd@',
      );
      expect(sign, expected);
    });

    test('generates correct Sign for QRCode+Time', () {
      final qrCode =
          'AB4035960E1B59CC6C4AFEFD2E76C4DE7403FC5DE0B19C3FDEDE13A9C606F4A69DB97ADB104353CC7E84DA2ABC7696CAB747F464D8CB2E51EB8D3352E792F926D2ED025B9706A4FE770408207BD2170B1C310D63FA738C30,12066';
      final sign = EcardService.generateSign([qrCode, '20260409174423']);
      expect(sign, '5a4f84ece9fc4b258fd5a8261910aec3');
    });
  });

  group('EcardService.studentIdToAccNum', () {
    test('strips leading zeros', () {
      expect(EcardService.studentIdToAccNum('00213544'), '213544');
    });

    test('returns same value when no leading zeros', () {
      expect(EcardService.studentIdToAccNum('213544'), '213544');
    });

    test('handles single digit', () {
      expect(EcardService.studentIdToAccNum('0001'), '1');
    });
  });

  group('EcardService.tripleBase64Encode/Decode', () {
    test('encodes 213544 to expected triple Base64', () {
      expect(EcardService.tripleBase64Encode('213544'), 'VFdwRmVrNVVVVEE9');
    });

    test('decodes VFdwRmVrNVVVVEE9 back to 213544', () {
      expect(EcardService.tripleBase64Decode('VFdwRmVrNVVVVEE9'), '213544');
    });

    test('encodes 1 to expected triple Base64', () {
      expect(EcardService.tripleBase64Encode('1'), 'VFZFOVBRPT0=');
    });

    test('decodes VFZFOVBRPT0= back to 1', () {
      expect(EcardService.tripleBase64Decode('VFZFOVBRPT0='), '1');
    });

    test('round-trip encode/decode', () {
      const values = ['12345', 'abc', '213544', '1'];
      for (final v in values) {
        expect(
          EcardService.tripleBase64Decode(EcardService.tripleBase64Encode(v)),
          v,
        );
      }
    });
  });

  group('EcardService.formatTime', () {
    test('formats DateTime as yyyymmddhhmmss', () {
      final dt = DateTime(2026, 4, 9, 17, 44, 34);
      expect(EcardService.formatTime(dt), '20260409174434');
    });

    test('pads single-digit months/days/hours', () {
      final dt = DateTime(2026, 1, 5, 3, 7, 9);
      expect(EcardService.formatTime(dt), '20260105030709');
    });
  });

  group('QRCodeInitResult', () {
    test('isSuccess is true when qrCode is set and no error', () {
      const result = QRCodeInitResult(accNum: '123', qrCode: 'QR');
      expect(result.isSuccess, true);
    });

    test('isSuccess is false when error is set', () {
      const result = QRCodeInitResult(error: 'failed');
      expect(result.isSuccess, false);
    });

    test('isSuccess is false when qrCode is null', () {
      const result = QRCodeInitResult(accNum: '123');
      expect(result.isSuccess, false);
    });
  });

  group('QRCodeInfoResult', () {
    test('isUsed when code is 1 and tradeAmt is non-empty', () {
      const result = QRCodeInfoResult(code: '1', tradeAmt: '5.00');
      expect(result.isUsed, true);
      expect(result.isPending, false);
    });

    test('isPending when code is 1 but tradeAmt is empty', () {
      const result = QRCodeInfoResult(code: '1');
      expect(result.isUsed, false);
      expect(result.isPending, true);
    });

    test('isPending when code is 0', () {
      const result = QRCodeInfoResult(code: '0');
      expect(result.isUsed, false);
      expect(result.isPending, true);
    });

    test('isPending when code is empty', () {
      const result = QRCodeInfoResult(code: '');
      expect(result.isPending, true);
    });
  });
}
