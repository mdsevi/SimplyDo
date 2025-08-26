import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../character/profile.dart';
import '../models/shop_item.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  late Box<ShopItem> shopBox;
  late Box<Profile> profileBox;

  @override
  void initState() {
    super.initState();
    // Use your existing box names
    shopBox = Hive.box<ShopItem>('shopBox');
    profileBox = Hive.box<Profile>('profileBox');
    _ensurePotionExists();
  }

  // ---------- helpers ----------
  bool _isDefaultPotion(ShopItem i) {
    // robust check: name OR type+heal
    final isPotionType = (i.type?.toLowerCase() == 'potion');
    final hasHeal = (i.healAmount ?? 0) > 0;
    return i.name == 'Health Potion' || (isPotionType && hasHeal);
  }

  Future<void> _ensurePotionExists() async {
    final exists = shopBox.values.any(_isDefaultPotion);
    if (!exists) {
      await shopBox.add(
        ShopItem(
          name: 'Health Potion',
          description: 'Restores 20 HP',
          price: 10,
          type: 'potion',
          healAmount: 20,
        ),
      );
    }
  }

  Future<void> _deleteItem(int index, ShopItem item) async {
    if (_isDefaultPotion(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Default Health Potion cannot be deleted."),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Item"),
        content: Text("Are you sure you want to delete '${item.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await shopBox.deleteAt(index);
    }
  }

  void _editItem(int index, ShopItem item) {
    if (_isDefaultPotion(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Default Health Potion cannot be edited."),
        ),
      );
      return;
    }

    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toString());
    final descController = TextEditingController(text: item.description ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Reward"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Price"),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final parsedPrice = int.tryParse(priceController.text);
              if (parsedPrice == null || parsedPrice < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid price.")),
                );
                return;
              }

              item
                ..name = nameController.text.trim()
                ..price = parsedPrice
                ..description = descController.text.trim()
                ..type = 'reward'; // enforce reward type
              item.save();
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Reward"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Price"),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final parsedPrice = int.tryParse(priceController.text);
              if (parsedPrice == null || parsedPrice < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid price.")),
                );
                return;
              }

              final newItem = ShopItem(
                name: nameController.text.trim(),
                price: parsedPrice,
                type: 'reward', // force rewards
                description: descController.text.trim().isEmpty
                    ? null
                    : descController.text.trim(),
                healAmount: null,
              );
              shopBox.add(newItem);
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _buyItem(ShopItem item) {
    final profile = profileBox.get("player");
    if (profile == null) return;

    if (profile.coins < item.price) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Not enough coins!")));
      return;
    }

    profile.coins -= item.price;

    if (_isDefaultPotion(item)) {
      final heal = item.healAmount ?? 20;
      profile.health = min(profile.health + heal, profile.maxHealth);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${item.name} restored $heal HP!")),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Bought ${item.name}!")));
    }

    profile.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shop")),
      body: Column(
        children: [
          // Reactive coins + health
          ValueListenableBuilder(
            valueListenable: profileBox.listenable(),
            builder: (context, Box<Profile> box, _) {
              final profile = box.get("player");
              if (profile == null) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      "💰 Coins: ${profile.coins}",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      "❤️ Health: ${profile.health}",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              );
            },
          ),

          Expanded(
            child: ValueListenableBuilder(
              valueListenable: shopBox.listenable(),
              builder: (context, Box<ShopItem> box, _) {
                if (box.isEmpty) {
                  return const Center(child: Text("No items in shop"));
                }
                return ListView.builder(
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final item = box.getAt(index)!;
                    final isPotion = _isDefaultPotion(item);

                    return Dismissible(
                      key: Key('shop_${item.key}'),
                      direction: isPotion
                          ? DismissDirection.none
                          : DismissDirection.horizontal,
                      background: Container(
                        color: Colors.blue,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: const Icon(Icons.edit, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (isPotion) return false; // cannot edit/delete potion
                        if (direction == DismissDirection.startToEnd) {
                          _editItem(index, item);
                          return false;
                        } else if (direction == DismissDirection.endToStart) {
                          await _deleteItem(index, item);
                          return false;
                        }
                        return false;
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (((item.description ?? '').trim()).isNotEmpty)
                                Text((item.description ?? '').trim()),
                              Text("Price: ${item.price}"),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _buyItem(item),
                            child: const Text("Buy"),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}
