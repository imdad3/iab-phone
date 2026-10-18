import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IAB Phone Directory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
        useMaterial3: true,
      ),
      home: const GroupListScreen(),
    );
  }
}

// ১. গ্রুপ তালিকা স্ক্রিন
class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  void _showAddGroupDialog(BuildContext context) {
    final TextEditingController groupController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নতুন গ্রুপ যোগ করুন'),
        content: TextField(
          controller: groupController,
          decoration: const InputDecoration(
            labelText: 'গ্রুপের নাম',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              if (groupController.text.trim().isNotEmpty) {
                FirebaseFirestore.instance.collection('groups').add({
                  'name': groupController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('যোগ করুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ফোন ডিরেক্টরি (গ্রুপসমূহ)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('কোনো গ্রুপ নেই। নতুন গ্রুপ যোগ করুন।'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final group = docs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.folder)),
                  title: Text(group['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BranchListScreen(groupId: group.id, groupName: group['name']),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGroupDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ২. শাখা তালিকা স্ক্রিন
class BranchListScreen extends StatelessWidget {
  final String groupId;
  final String groupName;

  const BranchListScreen({super.key, required this.groupId, required this.groupName});

  void _showAddBranchDialog(BuildContext context) {
    final TextEditingController branchController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নতুন শাখা যোগ করুন'),
        content: TextField(
          controller: branchController,
          decoration: const InputDecoration(
            labelText: 'শাখার নাম',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () {
              if (branchController.text.trim().isNotEmpty) {
                FirebaseFirestore.instance.collection('branches').add({
                  'groupId': groupId,
                  'name': branchController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('যোগ করুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$groupName এর শাখাসমূহ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('branches')
            .where('groupId', isEqualTo: groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('এই গ্রুপে কোনো শাখা নেই। নতুন শাখা যোগ করুন।'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final branch = docs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.apartment)),
                  title: Text(branch['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContactListScreen(
                          groupId: groupId,
                          branchId: branch.id,
                          branchName: branch['name'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBranchDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ৩. ব্যক্তি ও যোগাযোগের তালিকা স্ক্রিন
class ContactListScreen extends StatelessWidget {
  final String groupId;
  final String branchId;
  final String branchName;

  const ContactListScreen({
    super.key,
    required this.groupId,
    required this.branchId,
    required this.branchName,
  });

  Future<void> _makeCall(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendSMS(String phone) async {
    final Uri uri = Uri(scheme: 'sms', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone, BuildContext context) async {
    String cleanNumber = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.startsWith('0')) {
      cleanNumber = '88$cleanNumber';
    } else if (!cleanNumber.startsWith('88')) {
      cleanNumber = '880$cleanNumber';
    }
    final Uri uri = Uri.parse("https://wa.me/$cleanNumber");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('হোয়াটসঅ্যাপ খোলা সম্ভব হয়নি')),
        );
      }
    }
  }

  void _copyAllNumbers(List<QueryDocumentSnapshot> docs, BuildContext context) {
    if (docs.isEmpty) return;
    final numbers = docs
        .map((doc) => (doc['phone'] ?? '').toString())
        .where((p) => p.isNotEmpty)
        .toList();

    Clipboard.setData(ClipboardData(text: numbers.join(', ')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${numbers.length}টি নম্বর একসাথে কপি করা হয়েছে!')),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নতুন ব্যক্তি যোগ করুন'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'নাম', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'মোবাইল নম্বর', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'ঠিকানা', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                FirebaseFirestore.instance.collection('contacts').add({
                  'groupId': groupId,
                  'branchId': branchId,
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('contacts')
          .where('branchId', isEqualTo: branchId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text(branchName),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              if (docs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy_all),
                  tooltip: 'সব নম্বর কপি করুন',
                  onPressed: () => _copyAllNumbers(docs, context),
                ),
            ],
          ),
          body: !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : docs.isEmpty
                  ? const Center(child: Text('এই শাখায় কোনো ব্যক্তি যুক্ত নেই।'))
                  : ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final contact = docs[index];
                        final name = contact['name'] ?? '';
                        final phone = contact['phone'] ?? '';
                        final address = contact['address'] ?? '';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 20,
                                      child: Icon(Icons.person),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text(phone, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                          if (address.isNotEmpty)
                                            Text(address, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.phone, color: Colors.green),
                                      tooltip: 'কল করুন',
                                      onPressed: () => _makeCall(phone),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.message, color: Colors.blue),
                                      tooltip: 'মেসেজ',
                                      onPressed: () => _sendSMS(phone),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                                      tooltip: 'হোয়াটসঅ্যাপ',
                                      onPressed: () => _openWhatsApp(phone, context),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, color: Colors.grey),
                                      tooltip: 'কপি',
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: phone));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('$phone কপি করা হয়েছে')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddContactDialog(context),
            child: const Icon(Icons.person_add),
          ),
        );
      },
    );
  }
}
