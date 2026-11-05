import 'package:flutter/material.dart';

import '../services/avatar_cast_service.dart';

/// Cast screen: pick the avatar that watches you, and hear a line before you
/// commit to it. Everything here is data — no new Kotlin per avatar.
class AvatarCastScreen extends StatefulWidget {
  const AvatarCastScreen({super.key, this.service = const AvatarCastService()});

  final AvatarCastService service;

  @override
  State<AvatarCastScreen> createState() => _AvatarCastScreenState();
}

class _AvatarCastScreenState extends State<AvatarCastScreen> {
  List<AvatarInfo> _avatars = const [];
  String? _selectedId;
  String? _line;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final avatars = await widget.service.list();
      final selected = await widget.service.selected();
      if (!mounted) return;
      setState(() {
        _avatars = avatars;
        _selectedId = selected ?? (avatars.isNotEmpty ? avatars.first.id : null);
        _error = avatars.isEmpty ? 'No persona.json found in assets/avatars/.' : null;
        _busy = false;
      });
      if (_selectedId != null) await _speak(_selectedId!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not load avatars: $e';
      });
    }
  }

  Future<void> _select(String id) async {
    await widget.service.select(id);
    if (!mounted) return;
    setState(() => _selectedId = id);
    await _speak(id);
  }

  Future<void> _speak(String id) async {
    final line = await widget.service.sampleLine(id: id, stage: 'impatient');
    if (!mounted) return;
    setState(() => _line = line);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cast an avatar')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                for (final avatar in _avatars)
                  Card(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 2,
                        color: avatar.id == _selectedId
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(avatar.name),
                      subtitle: Text(
                        '${avatar.tone}\nmax ${avatar.maxLinesPerDay} lines/day',
                      ),
                      isThreeLine: true,
                      trailing: avatar.id == _selectedId
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () => _select(avatar.id),
                    ),
                  ),
                const SizedBox(height: 24),
                if (_line != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _line!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => widget.service.mute(minutes: 30),
                  icon: const Icon(Icons.notifications_off_outlined),
                  label: const Text('Mute for 30 minutes'),
                ),
              ],
            ),
    );
  }
}
