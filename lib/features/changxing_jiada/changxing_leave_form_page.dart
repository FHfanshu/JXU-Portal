import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'changxing_area_picker_dialog.dart';
import 'changxing_jiada_form_validator.dart';
import 'changxing_jiada_model.dart';
import 'changxing_jiada_service.dart';

class ChangxingLeaveFormPage extends StatefulWidget {
  const ChangxingLeaveFormPage({
    super.key,
    required this.formType,
    this.applicationId,
  });

  final ChangxingFormType formType;
  final int? applicationId;

  @override
  State<ChangxingLeaveFormPage> createState() => _ChangxingLeaveFormPageState();
}

class _ChangxingLeaveFormPageState extends State<ChangxingLeaveFormPage> {
  final _reasonController = TextEditingController();
  final _detailAddressController = TextEditingController();
  final _userPhoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  final List<String> _trafficOptions = <String>[
    '公交车',
    '自驾',
    '飞机',
    '高铁',
    '火车',
    '轮船',
    '其他',
  ];

  bool _loading = true;
  bool _submitting = false;
  bool _uploadingAttachment = false;

  DateTime? _startTime;
  DateTime? _endTime;
  ChangxingAreaSelection? _areaSelection;
  final Set<String> _selectedTraffic = <String>{};

  String _imageMd5 = '';
  String _attachmentMd5 = '';
  String _attachmentLabel = '';

  ChangxingJiadaService get _service => ChangxingJiadaService.instance;

  bool get _isEdit => (widget.applicationId ?? 0) > 0;

  bool get _isLeaveRequest => widget.formType == ChangxingFormType.leaveRequest;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _detailAddressController.dispose();
    _userPhoneController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      if (_isEdit) {
        final detail = await _service.fetchApplicationDetail(
          widget.applicationId!,
        );
        _startTime = detail.startTime;
        _endTime = detail.endTime;
        _reasonController.text = detail.descr;
        _detailAddressController.text = detail.toAddr;
        _userPhoneController.text = detail.userPhone;
        _emergencyContactController.text = detail.emergencyContact;
        _emergencyPhoneController.text = detail.emergencyPhone;
        _imageMd5 = detail.img;
        _attachmentMd5 = detail.annex;
        _attachmentLabel = _attachmentMd5.isEmpty
            ? ''
            : '已上传附件（${_attachmentMd5.substring(0, 8)}...）';

        final rawTraffic = detail.trafficTool
            .split(',')
            .map((it) => it.trim())
            .where((it) => it.isNotEmpty)
            .toSet();
        _selectedTraffic
          ..clear()
          ..addAll(rawTraffic);

        if (detail.toAreaCode > 0) {
          _areaSelection = await _buildAreaSelection(detail.toAreaCode);
        }
      } else {
        final profile = await _service.fetchUserProfile();
        _userPhoneController.text = profile.phone;
        _emergencyContactController.text = profile.emergencyContact;
        _emergencyPhoneController.text = profile.emergencyPhone;
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('加载表单失败：$e');
      context.pop();
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<ChangxingAreaSelection?> _buildAreaSelection(int areaId) async {
    final parents = await _service.fetchAreaParents(areaId);
    if (parents.isEmpty) return null;
    final chain = parents.reversed.toList();
    final province = chain.isNotEmpty ? chain[0] : null;
    final city = chain.length > 1 ? chain[1] : null;
    final district = chain.length > 2 ? chain[2] : null;
    return ChangxingAreaSelection(
      id: areaId,
      province: province,
      city: city,
      district: district,
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? DateTime.now())
        : (_endTime ?? _startTime ?? DateTime.now());

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    final merged = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!mounted) return;
    setState(() {
      if (isStart) {
        _startTime = merged;
      } else {
        _endTime = merged;
      }
    });
  }

  Future<void> _pickArea() async {
    final selection = await showChangxingAreaPickerDialog(
      context: context,
      service: _service,
      initialAreaId: _areaSelection?.id,
    );
    if (selection == null || !mounted) return;
    setState(() => _areaSelection = selection);
  }

  Future<void> _pickAttachment() async {
    setState(() => _uploadingAttachment = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: <String>['doc', 'docx', 'xlsx', 'xls', 'txt', 'pdf'],
      );
      final picked = result?.files.single;
      if (picked == null || picked.path == null || picked.path!.isEmpty) {
        return;
      }

      final upload = await _service.uploadAttachment(picked.path!, picked.name);
      if (!mounted) return;
      setState(() {
        _attachmentMd5 = upload.md5;
        _attachmentLabel = picked.name;
      });
      _showSnackBar('附件上传成功');
    } catch (e) {
      _showSnackBar('附件上传失败：$e');
    } finally {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
      }
    }
  }

  Future<void> _submit() async {
    final startTime = _startTime;
    final endTime = _endTime;
    if (startTime == null || endTime == null) {
      _showSnackBar('请选择开始和结束时间');
      return;
    }

    final dateMessage = ChangxingFormValidator.validateDateOrder(
      startTime,
      endTime,
    );
    if (dateMessage != null) {
      _showSnackBar(dateMessage);
      return;
    }

    final reasonMessage = ChangxingFormValidator.validateReason(
      _reasonController.text,
      emptyMessage: _isLeaveRequest ? '请假理由为空' : '离校事由为空',
      tooLongMessage: _isLeaveRequest ? '请假事由过长，最多200字' : '离校事由过长，最多200字',
    );
    if (reasonMessage != null) {
      _showSnackBar(reasonMessage);
      return;
    }

    final contactMessage = ChangxingFormValidator.validateContactName(
      _emergencyContactController.text,
    );
    if (contactMessage != null) {
      _showSnackBar(contactMessage);
      return;
    }

    if (!ChangxingFormValidator.isPhone(_userPhoneController.text)) {
      _showSnackBar('请输入正确的本人联系方式');
      return;
    }

    if (!ChangxingFormValidator.isPhone(_emergencyPhoneController.text)) {
      _showSnackBar('请输入正确的紧急联系人手机号');
      return;
    }

    if (_selectedTraffic.isEmpty) {
      _showSnackBar('请选择出行交通方式');
      return;
    }

    if (_areaSelection == null) {
      _showSnackBar('请选择目的地');
      return;
    }

    if (ChangxingFormValidator.isBlank(_detailAddressController.text)) {
      _showSnackBar('请填写详细地址');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_isLeaveRequest) {
        await _service.submitLeaveRequest(
          id: widget.applicationId,
          startTime: startTime,
          endTime: endTime,
          descr: _reasonController.text.trim(),
          toAreaCode: _areaSelection!.id,
          toAddr: _detailAddressController.text.trim(),
          emergencyContact: _emergencyContactController.text.trim(),
          emergencyPhone: _emergencyPhoneController.text.trim(),
          userPhone: _userPhoneController.text.trim(),
          trafficTools: _selectedTraffic.toList(),
          img: _imageMd5,
          annex: _attachmentMd5,
        );
      } else {
        await _service.submitLeaveSchool(
          id: widget.applicationId,
          startTime: startTime,
          endTime: endTime,
          descr: _reasonController.text.trim(),
          toAreaCode: _areaSelection!.id,
          toAddr: _detailAddressController.text.trim(),
          emergencyContact: _emergencyContactController.text.trim(),
          emergencyPhone: _emergencyPhoneController.text.trim(),
          userPhone: _userPhoneController.text.trim(),
          trafficTools: _selectedTraffic.toList(),
        );
      }

      if (!mounted) return;
      _showSnackBar(_isEdit ? '修改成功' : '提交成功');
      context.pop(true);
    } catch (e) {
      _showSnackBar(_isEdit ? '修改失败：$e' : '提交失败：$e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _fmtDateTime(DateTime? value) {
    if (value == null) return '请选择';
    String two(int n) => n.toString().padLeft(2, '0');
    final local = value.toLocal();
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLeaveRequest ? '请假申请' : '离校登记';

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑$title' : title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('开始时间'),
                        subtitle: Text(_fmtDateTime(_startTime)),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: () => _pickDateTime(isStart: true),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('结束时间'),
                        subtitle: Text(_fmtDateTime(_endTime)),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: () => _pickDateTime(isStart: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '本人联系方式',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emergencyContactController,
                  decoration: const InputDecoration(
                    labelText: '紧急联系人',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '联系人电话',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('出行交通方式', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _trafficOptions
                      .map(
                        (option) => FilterChip(
                          label: Text(option),
                          selected: _selectedTraffic.contains(option),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTraffic.add(option);
                              } else {
                                _selectedTraffic.remove(option);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: _isLeaveRequest ? '请假事由' : '离校事由',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('目的地'),
                    subtitle: Text(_areaSelection?.displayName ?? '请选择省份/市/区'),
                    trailing: const Icon(Icons.place_outlined),
                    onTap: _pickArea,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _detailAddressController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '详细地址',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_isLeaveRequest) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      title: const Text('附件'),
                      subtitle: Text(
                        _attachmentLabel.isEmpty ? '未上传' : _attachmentLabel,
                      ),
                      trailing: _uploadingAttachment
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      onTap: _uploadingAttachment ? null : _pickAttachment,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(
                    _submitting ? '提交中...' : (_isEdit ? '确认修改' : '提交'),
                  ),
                ),
              ],
            ),
    );
  }
}
