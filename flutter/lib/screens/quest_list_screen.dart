import 'package:flutter/material.dart';
import '../models/pillar.dart';
import '../models/quest.dart';
import '../services/quest_service.dart';
import '../widgets/quest_card.dart';
import 'quest_detail_screen.dart';

class QuestListScreen extends StatefulWidget {
  final PillarType? initialPillar;

  const QuestListScreen({super.key, this.initialPillar});

  @override
  State<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends State<QuestListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _questService = QuestService();

  static const _tabs = [null, ...PillarType.values];

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialPillar != null
        ? _tabs.indexOf(widget.initialPillar)
        : 0;
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('Quests', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((p) {
            if (p == null) return const Tab(text: 'All');
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p.icon, size: 14),
                  const SizedBox(width: 4),
                  Text(p.shortLabel),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((p) => _QuestTab(pillar: p)).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGlobalQuestBrowser,
        icon: const Icon(Icons.add),
        label: const Text('Browse All'),
      ),
    );
  }

  void _showGlobalQuestBrowser() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GlobalQuestBrowser(),
    );
  }
}

class _QuestTab extends StatelessWidget {
  final PillarType? pillar;
  const _QuestTab({this.pillar});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserQuest>>(
      stream: QuestService().watchActiveAndAvailableQuests(pillar: pillar),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final quests = snap.data ?? [];
        if (quests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_task, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'No quests here yet.\nTap "Browse All" to add quests.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: quests.length,
          itemBuilder: (ctx, i) => QuestCard(
            quest: quests[i],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => QuestDetailScreen(quest: quests[i])),
            ),
          ),
        );
      },
    );
  }
}

class _GlobalQuestBrowser extends StatefulWidget {
  @override
  State<_GlobalQuestBrowser> createState() => _GlobalQuestBrowserState();
}

class _GlobalQuestBrowserState extends State<_GlobalQuestBrowser> {
  final _questService = QuestService();
  List<GlobalQuestDefinition>? _globalQuests;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _questService.fetchGlobalQuests().then((quests) {
      if (mounted) setState(() { _globalQuests = quests; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Quest Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _globalQuests?.length ?? 0,
                    itemBuilder: (ctx, i) {
                      final q = _globalQuests![i];
                      return _GlobalQuestTile(quest: q);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GlobalQuestTile extends StatefulWidget {
  final GlobalQuestDefinition quest;
  const _GlobalQuestTile({required this.quest});

  @override
  State<_GlobalQuestTile> createState() => _GlobalQuestTileState();
}

class _GlobalQuestTileState extends State<_GlobalQuestTile> {
  bool _activating = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.quest;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: q.pillar.lightColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(q.pillar.icon, color: q.pillar.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '+${q.xpReward} XP · ${q.recurrence.label}',
                    style: TextStyle(fontSize: 12, color: q.pillar.color),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: _activating ? null : () async {
                setState(() => _activating = true);
                try {
                  await QuestService().activateQuest(q.questId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${q.name} activated!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _activating = false);
                }
              },
              child: _activating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
