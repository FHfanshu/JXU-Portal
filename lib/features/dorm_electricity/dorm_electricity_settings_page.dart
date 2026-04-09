import 'package:flutter/material.dart';

import 'dorm_electricity_service.dart';

class DormElectricitySettingsPage extends StatefulWidget {
  const DormElectricitySettingsPage({super.key});

  @override
  State<DormElectricitySettingsPage> createState() =>
      _DormElectricitySettingsPageState();
}

class _DormElectricitySettingsPageState
    extends State<DormElectricitySettingsPage> {
  final _service = DormElectricityService.instance;

  List<DormBuilding> _buildings = [];
  List<DormRoom> _rooms = [];

  DormBuilding? _selectedBuilding;
  DormRoom? _selectedRoom;

  bool _loadingBuildings = true;
  bool _loadingRooms = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    try {
      final buildings = await _service.fetchBuildings();
      if (!mounted) return;
      setState(() {
        _buildings = buildings;
        _loadingBuildings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载楼幢列表失败';
        _loadingBuildings = false;
      });
    }
  }

  Future<void> _onBuildingChanged(DormBuilding? building) async {
    if (building == null) return;
    setState(() {
      _selectedBuilding = building;
      _selectedRoom = null;
      _rooms = [];
      _loadingRooms = true;
    });
    try {
      final rooms = await _service.fetchRooms(building.buildingId);
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _loadingRooms = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载房间列表失败';
        _loadingRooms = false;
      });
    }
  }

  Future<void> _save() async {
    final building = _selectedBuilding;
    final room = _selectedRoom;
    if (building == null || room == null) return;

    setState(() => _saving = true);
    await _service.saveRoomConfig(DormRoomConfig(
      communityId: building.communityId,
      buildingId: building.buildingId,
      floorId: room.floorId,
      roomId: room.roomId,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('寝室配置成功')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择寝室')),
      body: _loadingBuildings
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _loadingBuildings = true;
                          });
                          _loadBuildings();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<DormBuilding>(
                        decoration: const InputDecoration(
                          labelText: '园区 / 楼幢',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _selectedBuilding,
                        items: _buildings.map((b) {
                          return DropdownMenuItem(
                            value: b,
                            child: Text(
                              '${b.communityName}  ${b.buildingName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _onBuildingChanged,
                      ),
                      const SizedBox(height: 20),
                      if (_loadingRooms)
                        const Center(child: CircularProgressIndicator())
                      else
                        DropdownButtonFormField<DormRoom>(
                          decoration: const InputDecoration(
                            labelText: '楼层 / 房间号',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: _selectedRoom,
                          items: _rooms.map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Text('${r.floorName}  ${r.roomName}号'),
                            );
                          }).toList(),
                          onChanged: _rooms.isEmpty
                              ? null
                              : (r) => setState(() => _selectedRoom = r),
                        ),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: (_selectedBuilding != null &&
                                _selectedRoom != null &&
                                !_saving)
                            ? _save
                            : null,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('保存'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
