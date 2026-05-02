bool hasAdminPerm(Iterable<String> permKeys) {
  final perms = permKeys.map((e) => e.trim()).where((e) => e.isNotEmpty);
  return perms.any(
    (p) =>
        p.startsWith('user:') ||
        p.startsWith('role:') ||
        p.startsWith('all-email:') ||
        p.startsWith('setting:') ||
        p.startsWith('reg-key:') ||
        p.startsWith('analysis:'),
  );
}

bool isAdminFromUserInfo(Map<String, dynamic> info) {
  final perms = ((info['permKeys'] as List?) ?? const []).map((e) => e.toString());
  if (hasAdminPerm(perms)) return true;

  final isAdminLike =
      info['isAdmin'] == true ||
      info['admin'] == true ||
      info['isRoot'] == true;
  if (isAdminLike) return true;

  final roleName = (info['roleName']?.toString() ?? '').toLowerCase();
  final roleCode = (info['roleCode']?.toString() ?? '').toLowerCase();
  if (roleName.contains('admin') || roleName.contains('管理员') || roleCode.contains('admin')) {
    return true;
  }

  final roleObj = info['role'];
  if (roleObj is Map) {
    final roleMap = Map<String, dynamic>.from(roleObj);
    final nestedRoleName = (roleMap['name']?.toString() ?? '').toLowerCase();
    final nestedRoleCode = (roleMap['code']?.toString() ?? '').toLowerCase();
    final nestedRoleId = int.tryParse((roleMap['roleId'] ?? roleMap['id'] ?? '').toString());
    final nestedPerms = ((roleMap['permKeys'] as List?) ?? const []).map((e) => e.toString());
    if (nestedRoleName.contains('admin') || nestedRoleName.contains('管理员') || nestedRoleCode.contains('admin')) {
      return true;
    }
    if (nestedRoleId == 1 || nestedRoleId == 0) {
      return true;
    }
    if (hasAdminPerm(nestedPerms)) {
      return true;
    }
  }

  final typeRaw = info['type'] ?? info['userType'];
  final typeValue = int.tryParse(typeRaw?.toString() ?? '');
  if (typeValue == 0) return true;

  final roleIdValue = int.tryParse((info['roleId'] ?? '').toString());
  if (roleIdValue == 1) return true;

  return false;
}
