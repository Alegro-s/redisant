class LynxLuaWebRuntime {
  LynxLuaWebRuntime._();
  static LynxLuaWebRuntime? create(dynamic grids) => null;
  String? load(String code) => 'Lua web runtime only on Web';
  String? runFrame(double dt, Map<String, dynamic> globals) => null;
  void dispose() {}
}

bool get lynxLuaWebAvailable => false;
