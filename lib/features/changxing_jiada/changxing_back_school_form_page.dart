import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'changxing_area_picker_dialog.dart';
import 'changxing_jiada_form_validator.dart';
import 'changxing_jiada_model.dart';
import 'changxing_jiada_service.dart';

class ChangxingBackSchoolFormPage extends StatefulWidget {
  const ChangxingBackSchoolFormPage({super.key, this.applicationId});

  final int? applicationId;

  @override
  State<ChangxingBackSchoolFormPage> createState() =>
      _ChangxingBackSchoolFormPageState();
}

class _ChangxingBackSchoolFormPageState
    extends State<ChangxingBackSchoolFormPage> {
  final _userPhoneController = TextEditingController();
  final _nativePlaceController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _trafficDetailController = TextEditingController();
  final _notBackReasonController = TextEditingController();

  final List<String> _trafficOptions = <String>['飞机', '火车', '客车', '自驾'];

  bool _loading = true;
  bool _submitting = false;
  bool _uploadingAttachment = false;

  int? _backStatus;
  bool _promiseChecked = false;
  DateTime? _reportDate;
  String? _trafficTool;

  ChangxingAreaSelection? _areaSelection;

  String _imageMd5 = '';
  String _attachmentMd5 = '';
  String _attachmentLabel = '';

  ChangxingJiadaService get _service => ChangxingJiadaService.instance;

  bool get _isEdit => (widget.applicationId ?? 0) > 0;

  bool get _isNormalBack => _backStatus == 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _userPhoneController.dispose();
    _nativePlaceController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _trafficDetailController.dispose();
    _notBackReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      if (_isEdit) {
        final detail = await _service.fetchApplicationDetail(
          widget.applicationId!,
        );
        _userPhoneController.text = detail.userPhone;
        _nativePlaceController.text = detail.nativePlace;
        _emergencyContactController.text = detail.emergencyContact;
        _emergencyPhoneController.text = detail.emergencyPhone;
        _reportDate = detail.startTime;
        _backStatus = detail.backStatus;
        _notBackReasonController.text = detail.notBackReason;
        _imageMd5 = detail.img;
        _attachmentMd5 = detail.annex;
        _attachmentLabel = _attachmentMd5.isEmpty
            ? ''
            : '已上传附件（${_attachmentMd5.substring(0, 8)}...）';

        if (detail.fromAreaCode > 0) {
          _areaSelection = await _buildAreaSelection(detail.fromAreaCode);
        }

        if (_trafficOptions.contains(detail.trafficTool)) {
          _trafficTool = detail.trafficTool;
          _trafficDetailController.text = detail.trafficDetail;
        } else {
          _trafficTool = null;
          _trafficDetailController.text = detail.trafficDetail.isNotEmpty
              ? detail.trafficDetail
              : detail.trafficTool;
        }

        _promiseChecked = _backStatus == 0;
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

  Future<void> _pickArea() async {
    final selection = await showChangxingAreaPickerDialog(
      context: context,
      service: _service,
      initialAreaId: _areaSelection?.id,
    );
    if (selection == null || !mounted) return;
    setState(() => _areaSelection = selection);
  }

  Future<void> _pickReportDate() async {
    final initial = _reportDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null || !mounted) return;
    setState(() => _reportDate = date);
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
    if (_backStatus == null) {
      _showSnackBar('请选择报到状态');
      return;
    }

    if (!ChangxingFormValidator.isPhone(_userPhoneController.text)) {
      _showSnackBar('请输入正确的手机号');
      return;
    }

    final contactMessage = ChangxingFormValidator.validateContactName(
      _emergencyContactController.text,
    );
    if (contactMessage != null) {
      _showSnackBar(contactMessage);
      return;
    }

    if (!ChangxingFormValidator.isPhone(_emergencyPhoneController.text)) {
      _showSnackBar('请输入正确的紧急联系人手机号');
      return;
    }

    if (ChangxingFormValidator.isBlank(_nativePlaceController.text)) {
      _showSnackBar('请填写籍贯');
      return;
    }

    if (_areaSelection == null) {
      _showSnackBar('请选择生源所在地');
      return;
    }

    if (_isNormalBack) {
      if (_reportDate == null) {
        _showSnackBar('请选择报到日期');
        return;
      }

      if ((_trafficTool ?? '').isEmpty) {
        _showSnackBar('请选择交通方式');
        return;
      }

      if (ChangxingFormValidator.isBlank(_trafficDetailController.text)) {
        _showSnackBar('请填写交通信息详情');
        return;
      }

      if (!_promiseChecked) {
        _showSnackBar('如正常报到，请勾选承诺');
        return;
      }
    } else {
      final notBackReasonMessage = ChangxingFormValidator.validateNotBackReason(
        _notBackReasonController.text,
      );
      if (notBackReasonMessage != null) {
        _showSnackBar(notBackReasonMessage);
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final enabled = await _service.fetchFanxiaoEnableFlag();
      if (!enabled) {
        _showSnackBar('报到登记暂未开放，请联系管理员');
        return;
      }

      await _service.submitBackSchool(
        id: widget.applicationId,
        userPhone: _userPhoneController.text.trim(),
        startTime: _reportDate ?? DateTime.now(),
        trafficTool: _trafficTool ?? '',
        trafficDetail: _trafficDetailController.text.trim(),
        nativePlace: _nativePlaceController.text.trim(),
        fromAreaCode: _areaSelection!.id,
        emergencyContact: _emergencyContactController.text.trim(),
        emergencyPhone: _emergencyPhoneController.text.trim(),
        backStatus: _backStatus!,
        notBackReason: _isNormalBack
            ? ''
            : _notBackReasonController.text.trim(),
        img: _imageMd5,
        annex: _attachmentMd5,
      );

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

  String _fmtDate(DateTime? value) {
    if (value == null) return '请选择';
    String two(int n) => n.toString().padLeft(2, '0');
    final local = value.toLocal();
    return '${local.year}/${two(local.month)}/${two(local.day)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑返校登记' : '返校登记')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _userPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('报到状态', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 0, label: Text('正常报到')),
                    ButtonSegment<int>(value: 1, label: Text('暂缓报到')),
                    ButtonSegment<int>(value: 2, label: Text('不报到')),
                  ],
                  emptySelectionAllowed: true,
                  selected: _backStatus == null
                      ? const <int>{}
                      : <int>{_backStatus!},
                  onSelectionChanged: (selection) {
                    final value = selection.isEmpty ? null : selection.first;
                    setState(() {
                      _backStatus = value;
                      _promiseChecked = value == 0;
                    });
                  },
                ),
                if (_isNormalBack)
                  CheckboxListTile(
                    value: _promiseChecked,
                    onChanged: (value) {
                      setState(() => _promiseChecked = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('承诺：本人已熟悉开学报到要求'),
                  ),
                if (!_isNormalBack) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notBackReasonController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: '无法正常报到原因',
                      border: OutlineInputBorder(),
                      helperText: '不少于10个字',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _nativePlaceController,
                  decoration: const InputDecoration(
                    labelText: '籍贯',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('生源所在地'),
                    subtitle: Text(_areaSelection?.displayName ?? '请选择省份/市/区'),
                    trailing: const Icon(Icons.place_outlined),
                    onTap: _pickArea,
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
                if (_isNormalBack) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      title: const Text('报到日期'),
                      subtitle: Text(_fmtDate(_reportDate)),
                      trailing: const Icon(Icons.event_outlined),
                      onTap: _pickReportDate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _trafficTool,
                    items: _trafficOptions
                        .map(
                          (it) => DropdownMenuItem<String>(
                            value: it,
                            child: Text(it),
                          ),
                        )
                        .toList(),
                    decoration: const InputDecoration(
                      labelText: '交通方式',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _trafficTool = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _trafficDetailController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '交通信息详情',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
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
