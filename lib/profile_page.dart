import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 新增

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  String _authMode = 'login'; // or 'register'
  String? _error;
  String _nickname = 'User';

  final _firestore = FirebaseFirestore.instance; // Firestore 实例

  // 🔐 登录
  Future<void> _signIn() async {
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      _emailCtrl.clear();
      _passwordCtrl.clear();
      await _loadNickname(result.user);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  // 🧑‍🎓 注册 + 保存初始昵称
  Future<void> _register() async {
    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      _emailCtrl.clear();
      _passwordCtrl.clear();

      // 默认昵称为邮箱前缀
      final defaultNickname = _emailCtrl.text.trim().split('@')[0];
      await _firestore.collection('users').doc(result.user!.uid).set({
        'nickname': defaultNickname,
      });

      setState(() {
        _nickname = defaultNickname;
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  // ✉️ 密码重置
  Future<void> _resetPassword() async {
    if (_emailCtrl.text.isEmpty) {
      setState(() => _error = '请输入邮箱');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('重置邮件已发送')));
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  // 🔒 退出
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    setState(() {
      _nickname = 'User';
    });
  }

  // 🔁 加载昵称
  Future<void> _loadNickname(User? user) async {
    if (user == null) return;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        _nickname = doc.data()?['nickname'] ?? 'User';
      });
    }
  }

  // ✏️ 修改昵称
  void _editNickname() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _nickname);
        return AlertDialog(
          title: const Text('修改昵称'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '请输入昵称'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final newName =
                    controller.text.trim().isEmpty
                        ? 'User'
                        : controller.text.trim();
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final userDoc = FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid);
                  final docSnapshot = await userDoc.get();

                  if (docSnapshot.exists) {
                    await userDoc.update({'nickname': newName});
                  } else {
                    await userDoc.set({'nickname': newName});
                  }

                  setState(() {
                    _nickname = newName;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // 登录界面
  Widget _buildAuthForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Sign in',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap:
              () => setState(() {
                _authMode = _authMode == 'login' ? 'register' : 'login';
                _error = null;
              }),
          child: Text(
            _authMode == 'login'
                ? "Don't have an account? Register"
                : "Already have an account? Login",
            style: const TextStyle(color: Color.fromARGB(255, 131, 104, 178)),
          ),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _resetPassword,
            child: const Text(
              'Forgot password?',
              style: TextStyle(color: Colors.deepPurple),
            ),
          ),
        ),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
        ],
        ElevatedButton(
          onPressed: _authMode == 'login' ? _signIn : _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 0, 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 14),
          ),
          child: Text(
            _authMode == 'login' ? 'Sign in' : 'Register',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  // 个人资料界面
  Widget _buildProfile(User user) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const CircleAvatar(
          radius: 60,
          backgroundImage: AssetImage('assets/images/ProfilePicture.jpg'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _nickname,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            IconButton(
              onPressed: _editNickname,
              icon: const Icon(Icons.edit, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(user.email ?? '', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('退出登录'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user != null && _nickname == 'User') {
          _loadNickname(user); // 仅首次加载
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Me'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: user == null ? _buildAuthForm() : _buildProfile(user),
            ),
          ),
        );
      },
    );
  }
}
