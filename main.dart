import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// --- অ্যাডমিন সিকিউরিটি পিন (এখানে আপনার পছন্দমতো পিন দিন) ---
const String APP_ADMIN_PIN = "1234"; 

// অ্যাডমিন মোড ট্র্যাকার
final ValueNotifier<bool> isAdminNotifier = ValueNotifier<bool>(false);

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

// অ্যাডমিন আনলক/লক ডায়ালগ
void showAdminPinDialog(BuildContext context) {
  final pinController = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('অ্যাডমিন ভেরিফিকেশন'),
      content: TextField(
        controller: pinController,
        keyboardType: TextInputType.number,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'গোপন পিন কোড দিন',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
        ElevatedButton(
          onPressed: () {
            if (pinController.text.trim() == APP_ADMIN_PIN) {
              isAdminNotifier.value = true;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('অ্যাডমিন মোড সক্রিয় হয়েছে! এখন এডিট/ডিলিট করতে পারবেন।')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ভুল পিন কোড! আবার চেষ্টা করুন।')),
              );
            }
          },
          child: const Text('আনলক'),
        ),
      ],
    ),
  );
}

// অ্যাপবারের জন্য সিকিউরিটি বাটন
Widget buildAdminLockButton(BuildContext context) {
  return ValueListenableBuilder<bool>(
    valueListenable: isAdminNotifier,
    builder: (context, isAdmin, child) {
      return IconButton(
        icon: Icon(
          isAdmin ? Icons.lock_open : Icons.lock,
          color: isAdmin ? Colors.amber : null,
        ),
        tooltip: isAdmin ? 'অ্যাডমিন মোড বন্ধ করুন' : 'অ্যাডমিন আনলক করুন',
        onPressed: () {
          if (isAdmin) {
            isAdminNotifier.value = false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('অ্যাডমিন মোড লক করা হয়েছে')),
            );
          } else {
            showAdminPinDialog(context);
          }
        },
      );
    },
  );
}

// ================= ১. গ্রুপ স্ক্রিন =================
class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  void _showAddGroupDialog(BuildContext context) {
    final groupController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নতুন গ্রুপ তৈরি করুন'),
        content: TextField(
          controller: groupController,
          decoration: const InputDecoration(labelText: 'গ্রুপের নাম', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
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
            child: const Text('তৈরি করুন'),
          ),
        ],
      ),
    );
  }

  void _showEditGroupDialog(BuildContext context, String docId, String currentName) {
    final groupController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('গ্রুপের নাম পরিবর্তন'),
        content: TextField(
          controller: groupController,
          decoration: const InputDecoration(labelText: 'নতুন নাম', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              if (groupController.text.trim().isNotEmpty) {
                FirebaseFirestore.instance.collection('groups').doc(docId).update({
                  'name': groupController.text.trim(),
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('আপডেট'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('গ্রুপ মুছে ফেলবেন?'),
        content: Text('আপনি কি নিশ্চিত যে "$name" গ্রুপটি মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('না')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              FirebaseFirestore.instance.collection('groups').doc(docId).delete();
              Navigator.pop(ctx);
            },
            child: const Text('হ্যাঁ, মুছুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isAdminNotifier,
      builder: (context, isAdmin, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('ফোন ডিরেক্টরি (গ্রুপসমূহ)'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [buildAdminLockButton(context)],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('groups').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('কোনো গ্রুপ নেই।'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final group = docs[index];
                  final groupName = group['name'] ?? '';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.folder)),
                      title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      trailing: isAdmin
                          ? PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showEditGroupDialog(context, group.id, groupName);
                                } else if (val == 'delete') {
                                  _confirmDelete(context, group.id, groupName);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('নাম পরিবর্তন')]),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('মুছে ফেলুন')]),
                                ),
                              ],
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BranchListScreen(groupId: group.id, groupName: groupName),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: isAdmin
              ? FloatingActionButton(
                  onPressed: () => _showAddGroupDialog(context),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }
}

// ================= ২. শাখা স্ক্রিন =================
class BranchListScreen extends StatelessWidget {
  final String groupId;
  final String groupName;

  const BranchListScreen({super.key, required this.groupId, required this.groupName});

  void _showAddBranchDialog(BuildContext context) {
    final branchController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নতুন শাখা তৈরি করুন'),
        content: TextField(
          controller: branchController,
          decoration: const InputDecoration(labelText: 'শাখার নাম', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
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
            child: const Text('তৈরি করুন'),
          ),
        ],
      ),
    );
  }

  void _showEditBranchDialog(BuildContext context, String docId, String currentName) {
    final branchController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('শাখার নাম পরিবর্তন'),
        content: TextField(
          controller: branchController,
          decoration: const InputDecoration(labelText: 'নতুন নাম', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              if (branchController.text.trim().isNotEmpty) {
                FirebaseFirestore.instance.collection('branches').doc(docId).update({
                  'name': branchController.text.trim(),
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('আপডেট'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBranch(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('শাখা মুছে ফেলবেন?'),
        content: Text('আপনি কি নিশ্চিত যে "$name" শাখাটি মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('না')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              FirebaseFirestore.instance.collection('branches').doc(docId).delete();
              Navigator.pop(ctx);
            },
            child: const Text('হ্যাঁ, মুছুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isAdminNotifier,
      builder: (context, isAdmin, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(groupName),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [buildAdminLockButton(context)],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('branches').where('groupId', isEqualTo: groupId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('এই গ্রুপে কোনো শাখা নেই।'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final branch = docs[index];
                  final branchName = branch['name'] ?? '';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.apartment)),
                      title: Text(branchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      trailing: isAdmin
                          ? PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showEditBranchDialog(context, branch.id, branchName);
                                } else if (val == 'delete') {
                                  _confirmDeleteBranch(context, branch.id, branchName);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('নাম পরিবর্তন')]),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('মুছে ফেলুন')]),
                                ),
                              ],
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ContactListScreen(
                              groupId: groupId,
                              branchId: branch.id,
                              branchName: branchName,
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
          floatingActionButton: isAdmin
              ? FloatingActionButton(
                  onPressed: () => _showAddBranchDialog(context),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }
}

// ================= ৩. কন্টাক্ট স্ক্রিন =================
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
    final numbers = docs.map((doc) => (doc['phone'] ?? '').toString()).where((p) => p.isNotEmpty).toList();
    Clipboard.setData(ClipboardData(text: numbers.join(', ')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${numbers.length}টি নম্বর একসাথে কপি করা হয়েছে!')),
    );
  }

  void _showContactDialog(BuildContext context, {String? docId, String? name, String? phone, String? address}) {
    final nameCtrl = TextEditingController(text: name ?? '');
    final phoneCtrl = TextEditingController(text: phone ?? '');
    final addressCtrl = TextEditingController(text: address ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(docId == null ? 'নতুন ব্যক্তি যোগ করুন' : 'তথ্য পরিবর্তন করুন'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'নাম', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'মোবাইল নম্বর', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'ঠিকানা/পদবি', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                // স্পষ্ট টাইপ Map<String, dynamic> দেওয়া হলো যাতে ফিল্ডভ্যালু ত্রুটি না আসে
                final Map<String, dynamic> data = {
                  'groupId': groupId,
                  'branchId': branchId,
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                };
                if (docId == null) {
                  data['createdAt'] = FieldValue.serverTimestamp();
                  FirebaseFirestore.instance.collection('contacts').add(data);
                } else {
                  FirebaseFirestore.instance.collection('contacts').doc(docId).update(data);
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteContact(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নম্বরটি মুছে ফেলবেন?'),
        content: Text('আপনি কি নিশ্চিত যে "$name"-এর নম্বর মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('না')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              FirebaseFirestore.instance.collection('contacts').doc(docId).delete();
              Navigator.pop(ctx);
            },
            child: const Text('হ্যাঁ, মুছুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isAdminNotifier,
      builder: (context, isAdmin, child) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('contacts').where('branchId', isEqualTo: branchId).snapshots(),
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
                  buildAdminLockButton(context),
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
                                        const CircleAvatar(radius: 20, child: Icon(Icons.person)),
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
                                        if (isAdmin)
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert),
                                            onSelected: (val) {
                                              if (val == 'edit') {
                                                _showContactDialog(context, docId: contact.id, name: name, phone: phone, address: address);
                                              } else if (val == 'delete') {
                                                _confirmDeleteContact(context, contact.id, name);
                                              }
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('এডিট')]),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('মুছুন')]),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const Divider(height: 18),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        IconButton(icon: const Icon(Icons.phone, color: Colors.green), tooltip: 'কল', onPressed: () => _makeCall(phone)),
                                        IconButton(icon: const Icon(Icons.message, color: Colors.blue), tooltip: 'মেসেজ', onPressed: () => _sendSMS(phone)),
                                        IconButton(icon: const Icon(Icons.chat, color: Color(0xFF25D366)), tooltip: 'হোয়াটসঅ্যাপ', onPressed: () => _openWhatsApp(phone, context)),
                                        IconButton(
                                          icon: const Icon(Icons.copy, color: Colors.grey),
                                          tooltip: 'কপি',
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: phone));
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$phone কপি হয়েছে')));
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
              floatingActionButton: isAdmin
                  ? FloatingActionButton(
                      onPressed: () => _showContactDialog(context),
                      child: const Icon(Icons.person_add),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
