import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'changxing_jiada_form_validator.dart';
import 'changxing_jiada_service.dart';

class ChangxingOvertimeFormPage extends StatefulWidget {
  const ChangxingOvertimeFormPage({super.key, this.applicationId});

  final int? applicationId;

  @override
  State<ChangxingOvertimeFormPage> createState() =>
      _ChangxingOvertimeFormPageState();
}

class _ChangxingOvertimeFormPageState extends State<ChangxingOvertimeFormPage> {
  final _reasonController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;

  ChangxingJiadaService get _service => ChangxingJiadaService.instance;

  bool get _isEdit => (widget.applicationId ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    if (!_isEdit) {
      setState(() => _loading = false);
      return;
    }

    try {
      final detail = await _service.fetchApplicationDetail(
        widget.applicationId!,
      );
      _reasonController.text = detail.descr;
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('加载表单失败：$e');
      context.pop();
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final reasonMessage = ChangxingFormValidator.validateReason(
      _reasonController.text,
      emptyMessage: '超时事由为空',
      tooLongMessage: '超时理由过长，最多200字',
    );
    if (reasonMessage != null) {
      _showSnackBar(reasonMessage);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.submitOvertime(
        id: widget.applicationId,
        descr: _reasonController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑超时登记' : '超时登记')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _reasonController,
                  minLines: 5,
                  maxLines: 7,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: '超时事由',
                    border: OutlineInputBorder(),
                    hintText: '请输入超时事由',
                  ),
                ),
                const SizedBox(height: 16),
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
