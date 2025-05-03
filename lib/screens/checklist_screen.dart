import 'package:duration_picker/duration_picker.dart';
import 'package:agixt/models/agixt/checklist.dart';
import 'package:agixt/screens/checklists/list_screen.dart';
import 'package:agixt/services/bluetooth_manager.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AGiXTChecklistPage extends StatefulWidget {
  const AGiXTChecklistPage({super.key});

  @override
  AGiXTChecklistPageState createState() => AGiXTChecklistPageState();
}

class AGiXTChecklistPageState extends State<AGiXTChecklistPage> {
  late Box<AGiXTChecklist> _checklistBox;

  @override
  void initState() {
    super.initState();
    _checklistBox = Hive.box<AGiXTChecklist>('agixtChecklistBox');
  }

  void _addChecklist() {
    showDialog(
      context: context,
      builder: (context) {
        return _AddListDialog(
          onAdd: (checklist) async {
            debugPrint('Adding checklist: $checklist');
            await _checklistBox.add(checklist);
            setState(() {});
          },
        );
      },
    );
  }

  void _editChecklist(int index) {
    final checklist = _checklistBox.getAt(index);
    if (checklist == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return _AddListDialog(
          onAdd: (checklist) async {
            await _checklistBox.putAt(index, checklist);
            setState(() {});
          },
          item: checklist,
        );
      },
    );
  }

  void _deleteChecklist(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this checklist?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _checklistBox.deleteAt(index);
                setState(() {});
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _playPauseChecklist(int index) {
    final checklist = _checklistBox.getAt(index);
    if (checklist == null) return;

    if (checklist.isShown) {
      checklist.hide();
    } else {
      checklist.showNow();
    }

    _checklistBox.putAt(index, checklist);
    setState(() {});
    final bt = BluetoothManager();
    bt.sync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Checklists'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addChecklist,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _checklistBox.listenable(),
        builder: (context, Box<AGiXTChecklist> box, _) {
          final checklists = box.values.toList();

          return ListView.builder(
            itemCount: checklists.length,
            itemBuilder: (context, index) {
              final checklist = checklists[index];
              return ListTile(
                title: Text(checklist.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: checklist.isShown
                            ? Icon(Icons.stop)
                            : Icon(Icons.play_arrow),
                        onPressed: () => _playPauseChecklist(index)),
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _editChecklist(index),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteChecklist(index),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChecklistItemsScreen(
                          index: index, checklist: checklist),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AddListDialog extends StatefulWidget {
  final Function(AGiXTChecklist) onAdd;
  final AGiXTChecklist? item;

  const _AddListDialog({required this.onAdd, this.item});

  @override
  _AddListDialogState createState() => _AddListDialogState();
}

class _AddListDialogState extends State<_AddListDialog> {
  TextEditingController titleController = TextEditingController();
  late Duration duration;

  @override
  void initState() {
    super.initState();
    titleController.text = widget.item?.name ?? '';
    duration = widget.item?.getDuration() ?? Duration(minutes: 5);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          widget.item == null ? Text('Add Checklist') : Text('Edit Checklist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(labelText: 'Title'),
            controller: titleController,
          ),
          SizedBox(height: 20),
          Text("Duration to show checklist"),
          DurationPicker(
            duration: duration,
            onChange: (value) {
              setState(() {
                duration = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (widget.item == null) {
              final newChecklist =
                  AGiXTChecklist(name: titleController.text, duration: 0);
              newChecklist.setDuration(duration);
              widget.onAdd(newChecklist);
            } else {
              widget.item!.name = titleController.text;
              widget.item!.setDuration(duration);
              widget.onAdd(widget.item!);
            }
            Navigator.of(context).pop();
          },
          child: widget.item == null ? Text('Add') : Text('Save'),
        ),
      ],
    );
  }
}
