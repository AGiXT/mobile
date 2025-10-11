import 'package:agixt/models/agixt/stop.dart';
import 'package:agixt/services/stops_manager.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class AGiXTStopPage extends StatefulWidget {
  const AGiXTStopPage({super.key});

  @override
  AGiXTStopPageState createState() => AGiXTStopPageState();
}

class AGiXTStopPageState extends State<AGiXTStopPage> {
  late LazyBox<AGiXTStopItem> _agixtStopBox;
  StopsManager stopsManager = StopsManager();

  @override
  void initState() {
    super.initState();
    _agixtStopBox = Hive.lazyBox<AGiXTStopItem>('agixtStopBox');
  }

  Future<void> _sortBox() async {
    final List<AGiXTStopItem> items = [];
    for (int i = 0; i < _agixtStopBox.length; i++) {
      final item = await _agixtStopBox.getAt(i);
      if (item != null) {
        items.add(item);
      }
    }

    items.sort((a, b) => a.time.compareTo(b.time));
    await _agixtStopBox.clear();
    await _agixtStopBox.addAll(items);

    stopsManager.reload();
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) {
        return _AddItemDialog(
          onAdd: (title, time) async {
            final newItem = AGiXTStopItem(title: title, time: time);
            await _agixtStopBox.add(newItem);
            await _sortBox();
            setState(() {});
          },
        );
      },
    );
  }

  void _editItem(int index) async {
    final item = await _agixtStopBox.getAt(index);
    if (!mounted) {
      return;
    }
    if (item != null) {
      showDialog(
        context: context,
        builder: (context) {
          return _AddItemDialog(
            item: item,
            onAdd: (title, time) async {
              final newItem = AGiXTStopItem(
                title: title,
                time: time,
                uuid: item.uuid,
              );
              await _agixtStopBox.putAt(index, newItem);
              await _sortBox();
              setState(() {});
            },
          );
        },
      );
    }
  }

  void _deleteItem(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this stop?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await _agixtStopBox.deleteAt(index);
                await _sortBox();
                if (!mounted) {
                  return;
                }
                setState(() {});
                navigator.pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<List<AGiXTStopItem>> _getItems() async {
    final List<AGiXTStopItem> items = [];
    for (int i = 0; i < _agixtStopBox.length; i++) {
      final item = await _agixtStopBox.getAt(i);
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AGiXT Stops'),
        actions: [IconButton(icon: Icon(Icons.add), onPressed: _addItem)],
      ),
      body: FutureBuilder<List<AGiXTStopItem>>(
        future: _getItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No stops available'));
          } else {
            final items = snapshot.data!;
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.time.year}-${item.time.month.toString().padLeft(2, '0')}-${item.time.day.toString().padLeft(2, '0')} ${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _editItem(index),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteItem(index),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final Function(String, DateTime) onAdd;
  final AGiXTStopItem? item;

  const _AddItemDialog({required this.onAdd, this.item});

  @override
  _AddItemDialogState createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  TextEditingController titleController = TextEditingController();
  late DateTime time;

  @override
  void initState() {
    super.initState();
    titleController.text = widget.item?.title ?? '';
    time = widget.item?.time ?? DateTime.now().add(Duration(hours: 1));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.item == null ? Text('Add Stop') : Text('Edit Stop'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(labelText: 'Title'),
            controller: titleController,
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Time: ${DateFormat('yyyy-MM-dd HH:mm').format(time.toLocal())}',
              ),
              SizedBox(width: 10),
              IconButton(
                onPressed: () async {
                  final dialogContext = context;
                  final DateTime? pickedDate = await showDatePicker(
                    context: dialogContext,
                    initialDate: widget.item?.time ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  if (pickedDate != null) {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: dialogContext,
                      initialTime:
                          widget.item != null
                              ? TimeOfDay.fromDateTime(widget.item!.time)
                              : TimeOfDay.now(),
                    );
                    if (!mounted || !dialogContext.mounted) {
                      return;
                    }
                    if (pickedTime != null) {
                      setState(() {
                        time = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                icon: Icon(Icons.edit),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onAdd(titleController.text, time);
            Navigator.of(context).pop();
          },
          child: widget.item == null ? Text('Add') : Text('Save'),
        ),
      ],
    );
  }
}
