import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// ১. সংগঠনের নাম, লোগো ও অ্যাডমিন সেটিংস
// ==========================================
const String ORG_NAME = "IAB নারায়ণগঞ্জ মহানগর";
const String APP_SUBTITLE = "অফিসিয়াল ফোন ডিরেক্টরি";

// এখানে আপনার লোগোর সরাসরি লিংকটি কোটেশনের (" ") ভেতর পেস্ট করুন:
const String LOGO_IMAGE_URL ="https://i.postimg.cc/fRb0b52y/FB-IMG-1792434797577.jpg"; 

// আপনার মাস্টার অ্যাডমিন পাসওয়ার্ড
const String APP_ADMIN_PIN = "2486"; 

// অ্যাডমিন স্টেট
final ValueNotifier<bool> isAdminNotifier = ValueNotifier<bool>(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ORG_NAME,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const GroupListScreen() : const LoginScreen(),
    );
  }
}

// লোগো দেখানোর রিইউজেবল উইজেট
Widget buildAppLogo({double size = 80}) {
  if (LOGO_IMAGE_URL.startsWith('http')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(
        LOGO_IMAGE_URL,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: const Color(0xFF00796B).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.account_balance_rounded, size: size * 0.55, color: const Color(0xFF00796B)),
        ),
      ),
    );
  }
  return Container(
    padding: EdgeInsets.all(size * 0.2),
    decoration: BoxDecoration(
      color: const Color(0xFF00796B).withOpacity(0.12),
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.account_balance_rounded, size: size * 0.55, color: const Color(0xFF00796B)),
  );
}

// ================= ০. লগইন / ভেরিফিকেশন স্ক্রিন =================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;

  Future<void> _handleLogin() async {
    final userId = _userIdCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (userId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ইউজার আইডি এবং পাসওয়ার্ড উভয়ই দিন')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      bool isValid = false;

      // মাস্টার অ্যাডমিন লগইন (admin / 2486)
      if (userId.toLowerCase() == "admin" && password == APP_ADMIN_PIN) {
        isValid = true;
        isAdminNotifier.value = true;
      } else {
        // ফায়ারস্টোর ইউজার যাচাই
        final query = await FirebaseFirestore.instance
            .collection('app_users')
            .where('userId', isEqualTo: userId)
            .where('password', isEqualTo: password)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          isValid = true;
        }
      }

      if (isValid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('logged_user_id', userId);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GroupListScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ভুল আইডি বা পাসওয়ার্ড! অ্যাডমিনের সাথে যোগাযোগ করুন।')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি ঘটেছে: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildAppLogo(size: 90),
              const SizedBox(height: 18),
              const Text(
                ORG_NAME,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
              ),
              const SizedBox(height: 4),
              const Text(
                APP_SUBTITLE,
                style: TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'অ্যাপে প্রবেশ করতে আপনাকে দেওয়া আইডি ও পাসওয়ার্ড দিন',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _userIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'ইউজার আইডি',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePin,
                decoration: InputDecoration(
                  labelText: 'পাসওয়ার্ড / পিন কোড',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('লগইন করুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// অ্যাডমিন আনলক পিন ডায়ালগ
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
          labelText: 'অ্যাডমিন পিন দিন',
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
                const SnackBar(content: Text('অ্যাডমিন মোড সক্রিয় হয়েছে!')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ভুল পিন কোড!')),
              );
            }
          },
          child: const Text('আনলক'),
        ),
      ],
    ),
  );
}

// অ্যাপবারের বাটনসমূহ
Widget buildAdminLockButton(BuildContext context) {
  return ValueListenableBuilder<bool>(
    valueListenable: isAdminNotifier,
    builder: (context, isAdmin, child) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.manage_accounts, color: Colors.amber),
              tooltip: 'ইউজার তৈরি ও পরিচালনা',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserManagementScreen()),
                );
              },
            ),
          IconButton(
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
          ),
        ],
      );
    },
  );
}

// ================= ১. ইউজার ম্যানেজমেন্ট স্ক্রিন =================
class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  void _showAddUserDialog(BuildContext context, {String? docId, String? name, String? userId, String? password}) {
    final nameCtrl = TextEditingController(text: name ?? '');
    final userCtrl = TextEditingController(text: userId ?? '');
    final passCtrl = TextEditingController(text: password ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(docId == null ? 'নতুন ইউজার যোগ করুন' : 'ইউজারের তথ্য পরিবর্তন'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ব্যবহারকারীর নাম', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'ইউজার আইডি (যেমন: user1 / মোবাইল নম্বর)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'পাসওয়ার্ড / কোড', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && userCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
                final data = {
                  'name': nameCtrl.text.trim(),
                  'userId': userCtrl.text.trim(),
                  'password': passCtrl.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                if (docId == null) {
                  data['createdAt'] = FieldValue.serverTimestamp();
                  FirebaseFirestore.instance.collection('app_users').add(data);
                } else {
                  FirebaseFirestore.instance.collection('app_users').doc(docId).update(data);
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

  void _deleteUser(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ইউজার বাতিল করবেন?'),
        content: Text('আপনি কি নিশ্চিত যে "$name"-কে মুছে ফেলতে চান? সে আর এই অ্যাপে ঢুকতে পারবে না।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('না')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              FirebaseFirestore.instance.collection('app_users').doc(docId).delete();
              Navigator.pop(ctx);
            },
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ইউজারদের তালিকা'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('app_users').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('কোনো সাধারণ ইউজার যুক্ত নেই। নিচে + বাটনে চাপ দিয়ে যোগ করুন।'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final user = docs[index];
              final name = user['name'] ?? '';
              final uId = user['userId'] ?? '';
              final pass = user['password'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('আইডি: $uId  |  পাসওয়ার্ড: $pass'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showAddUserDialog(context, docId: user.id, name: name, userId: uId, password: pass);
                      } else if (val == 'delete') {
                        _deleteUser(context, user.id, name);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('এডিট')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('মুছে ফেলুন')])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUserDialog(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

// ================= ২. গ্রুপ স্ক্রিন =================
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
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: buildAppLogo(size: 38),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ORG_NAME, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(APP_SUBTITLE, style: TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              buildAdminLockButton(context),
              PopupMenuButton<String>(
                onSelected: (val) async {
                  if (val == 'logout') {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    isAdminNotifier.value = false;
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 8), Text('লগআউট')]),
                  ),
                ],
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('groups').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>?;
                final bData = b.data() as Map<String, dynamic>?;
                final aTime = aData?['createdAt'] as Timestamp?;
                final bTime = bData?['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return aTime.compareTo(bTime);
              });

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
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('নাম পরিবর্তন')])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('মুছে ফেলুন')])),
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

// ================= ৩. শাখা স্ক্রিন =================
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
              final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>?;
                final bData = b.data() as Map<String, dynamic>?;
                final aTime = aData?['createdAt'] as Timestamp?;
                final bTime = bData?['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return aTime.compareTo(bTime);
              });

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
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('নাম পরিবর্তন')])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('মুছে ফেলুন')])),
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

// ================= ৪. কন্টাক্ট স্ক্রিন (কল, এসএমএস, ড্র্যাগ-সাজানো) =================
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

  Future<void> _onReorder(int oldIndex, int newIndex, List<QueryDocumentSnapshot> docs) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = docs.removeAt(oldIndex);
    docs.insert(newIndex, item);

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < docs.length; i++) {
      batch.update(docs[i].reference, {'order': i});
    }
    await batch.commit();
  }

  void _showContactDialog(BuildContext context, {String? docId, String? name, String? phone, String? address, int? currentCount}) {
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
                final Map<String, dynamic> data = {
                  'groupId': groupId,
                  'branchId': branchId,
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                };
                if (docId == null) {
                  data['createdAt'] = FieldValue.serverTimestamp();
                  data['order'] = currentCount ?? 0;
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

  Widget _buildContactCard(BuildContext context, QueryDocumentSnapshot contact, int index, bool isAdmin) {
    final name = contact['name'] ?? '';
    final phone = contact['phone'] ?? '';
    final address = contact['address'] ?? '';

    return Card(
      key: ValueKey(contact.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                if (isAdmin) ...[
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Icon(Icons.drag_handle, color: Colors.blueGrey, size: 26),
                    ),
                  ),
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
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('এডিট')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('মুছুন')])),
                    ],
                  ),
                ],
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
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isAdminNotifier,
      builder: (context, isAdmin, child) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('contacts').where('branchId', isEqualTo: branchId).snapshots(),
          builder: (context, snapshot) {
            final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
            docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>?;
              final bData = b.data() as Map<String, dynamic>?;
              final aOrder = aData?['order'] as num?;
              final bOrder = bData?['order'] as num?;
              if (aOrder != null && bOrder != null) {
                return aOrder.compareTo(bOrder);
              }
              final aTime = aData?['createdAt'] as Timestamp?;
              final bTime = bData?['createdAt'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return aTime.compareTo(bTime);
            });

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
                      : isAdmin
                          ? ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              itemCount: docs.length,
                              onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, docs),
                              itemBuilder: (context, index) {
                                return _buildContactCard(context, docs[index], index, true);
                              },
                            )
                          : ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                return _buildContactCard(context, docs[index], index, false);
                              },
                            ),
              floatingActionButton: isAdmin
                  ? FloatingActionButton(
                      onPressed: () => _showContactDialog(context, currentCount: docs.length),
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
