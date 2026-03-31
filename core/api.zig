const nux = @import("nux.zig");
pub const Collection = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const instantiate = struct {
			pub const Name = "instantiate";
			pub const Function = nux.Collection.instantiate;
		};
		pub const exportNode = struct {
			pub const Name = "exportNode";
			pub const Function = nux.Collection.exportNode;
		};
	};
	pub const Properties = struct {
	};
};
pub const Node = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const createPath = struct {
			pub const Name = "createPath";
			pub const Function = nux.Node.createPath;
		};
		pub const delete = struct {
			pub const Name = "delete";
			pub const Function = nux.Node.delete;
		};
		pub const exists = struct {
			pub const Name = "exists";
			pub const Function = nux.Node.exists;
		};
		pub const setName = struct {
			pub const Name = "setName";
			pub const Function = nux.Node.setName;
		};
		pub const dump = struct {
			pub const Name = "dump";
			pub const Function = nux.Node.dump;
		};
		pub const findGlobal = struct {
			pub const Name = "findGlobal";
			pub const Function = nux.Node.findGlobal;
		};
		pub const create = struct {
			pub const Name = "create";
			pub const Function = nux.Node.create;
		};
		pub const createNamed = struct {
			pub const Name = "createNamed";
			pub const Function = nux.Node.createNamed;
		};
		pub const find = struct {
			pub const Name = "find";
			pub const Function = nux.Node.find;
		};
		pub const createInstanceOf = struct {
			pub const Name = "createInstanceOf";
			pub const Function = nux.Node.createInstanceOf;
		};
		pub const getRoot = struct {
			pub const Name = "getRoot";
			pub const Function = nux.Node.getRoot;
		};
		pub const getParent = struct {
			pub const Name = "getParent";
			pub const Function = nux.Node.getParent;
		};
		pub const findChild = struct {
			pub const Name = "findChild";
			pub const Function = nux.Node.findChild;
		};
	};
	pub const Properties = struct {
		pub const Parent = struct {
			pub const Name = Node.Functions.getParent.Name[3..];
			pub const Getter = nux.Node.getParent;
		};
		pub const Root = struct {
			pub const Name = Node.Functions.getRoot.Name[3..];
			pub const Getter = nux.Node.getRoot;
		};
		pub const Name = struct {
			pub const Setter = nux.Node.setName;
		};
	};
};
pub const Component = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const add = struct {
			pub const Name = "add";
			pub const Function = nux.Component.add;
		};
		pub const remove = struct {
			pub const Name = "remove";
			pub const Function = nux.Component.remove;
		};
	};
	pub const Properties = struct {
	};
};
pub const Signal = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const emit = struct {
			pub const Name = "emit";
			pub const Function = nux.Signal.emit;
		};
	};
	pub const Properties = struct {
	};
};
pub const File = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const logGlob = struct {
			pub const Name = "logGlob";
			pub const Function = nux.File.logGlob;
		};
		pub const mount = struct {
			pub const Name = "mount";
			pub const Function = nux.File.mount;
		};
	};
	pub const Properties = struct {
	};
};
pub const Cart = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const writeGlob = struct {
			pub const Name = "writeGlob";
			pub const Function = nux.Cart.writeGlob;
		};
		pub const write = struct {
			pub const Name = "write";
			pub const Function = nux.Cart.write;
		};
		pub const begin = struct {
			pub const Name = "begin";
			pub const Function = nux.Cart.begin;
		};
	};
	pub const Properties = struct {
	};
};
pub const Transform = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const setPosition = struct {
			pub const Name = "setPosition";
			pub const Function = nux.Transform.setPosition;
		};
		pub const getScale = struct {
			pub const Name = "getScale";
			pub const Function = nux.Transform.getScale;
		};
		pub const setParent = struct {
			pub const Name = "setParent";
			pub const Function = nux.Transform.setParent;
		};
		pub const setRotation = struct {
			pub const Name = "setRotation";
			pub const Function = nux.Transform.setRotation;
		};
		pub const getParent = struct {
			pub const Name = "getParent";
			pub const Function = nux.Transform.getParent;
		};
		pub const setScale = struct {
			pub const Name = "setScale";
			pub const Function = nux.Transform.setScale;
		};
		pub const getPosition = struct {
			pub const Name = "getPosition";
			pub const Function = nux.Transform.getPosition;
		};
		pub const getRotation = struct {
			pub const Name = "getRotation";
			pub const Function = nux.Transform.getRotation;
		};
	};
	pub const Properties = struct {
		pub const Parent = struct {
			pub const Name = Transform.Functions.getParent.Name[3..];
			pub const Getter = nux.Transform.getParent;
			pub const Setter = nux.Transform.setParent;
		};
		pub const Rotation = struct {
			pub const Name = Transform.Functions.getRotation.Name[3..];
			pub const Getter = nux.Transform.getRotation;
			pub const Setter = nux.Transform.setRotation;
		};
		pub const Position = struct {
			pub const Name = Transform.Functions.getPosition.Name[3..];
			pub const Getter = nux.Transform.getPosition;
			pub const Setter = nux.Transform.setPosition;
		};
		pub const Scale = struct {
			pub const Name = Transform.Functions.getScale.Name[3..];
			pub const Getter = nux.Transform.getScale;
			pub const Setter = nux.Transform.setScale;
		};
	};
};
pub const Input = struct {
	pub const Enums = struct {
		pub const Key = struct {
			pub const Name = "Key";
			pub const is_bitfield = false;
			pub const Values = struct {
				pub const SPACE = struct {
					pub const Name = "SPACE";
					pub const Value = nux.Input.Key.space;
				};
				pub const APOSTROPHE = struct {
					pub const Name = "APOSTROPHE";
					pub const Value = nux.Input.Key.apostrophe;
				};
				pub const COMMA = struct {
					pub const Name = "COMMA";
					pub const Value = nux.Input.Key.comma;
				};
				pub const MINUS = struct {
					pub const Name = "MINUS";
					pub const Value = nux.Input.Key.minus;
				};
				pub const PERIOD = struct {
					pub const Name = "PERIOD";
					pub const Value = nux.Input.Key.period;
				};
				pub const SLASH = struct {
					pub const Name = "SLASH";
					pub const Value = nux.Input.Key.slash;
				};
				pub const NUM0 = struct {
					pub const Name = "NUM0";
					pub const Value = nux.Input.Key.num0;
				};
				pub const NUM1 = struct {
					pub const Name = "NUM1";
					pub const Value = nux.Input.Key.num1;
				};
				pub const NUM2 = struct {
					pub const Name = "NUM2";
					pub const Value = nux.Input.Key.num2;
				};
				pub const NUM3 = struct {
					pub const Name = "NUM3";
					pub const Value = nux.Input.Key.num3;
				};
				pub const NUM4 = struct {
					pub const Name = "NUM4";
					pub const Value = nux.Input.Key.num4;
				};
				pub const NUM5 = struct {
					pub const Name = "NUM5";
					pub const Value = nux.Input.Key.num5;
				};
				pub const NUM6 = struct {
					pub const Name = "NUM6";
					pub const Value = nux.Input.Key.num6;
				};
				pub const NUM7 = struct {
					pub const Name = "NUM7";
					pub const Value = nux.Input.Key.num7;
				};
				pub const NUM8 = struct {
					pub const Name = "NUM8";
					pub const Value = nux.Input.Key.num8;
				};
				pub const NUM9 = struct {
					pub const Name = "NUM9";
					pub const Value = nux.Input.Key.num9;
				};
				pub const SEMICOLON = struct {
					pub const Name = "SEMICOLON";
					pub const Value = nux.Input.Key.semicolon;
				};
				pub const EQUAL = struct {
					pub const Name = "EQUAL";
					pub const Value = nux.Input.Key.equal;
				};
				pub const A = struct {
					pub const Name = "A";
					pub const Value = nux.Input.Key.a;
				};
				pub const B = struct {
					pub const Name = "B";
					pub const Value = nux.Input.Key.b;
				};
				pub const C = struct {
					pub const Name = "C";
					pub const Value = nux.Input.Key.c;
				};
				pub const D = struct {
					pub const Name = "D";
					pub const Value = nux.Input.Key.d;
				};
				pub const E = struct {
					pub const Name = "E";
					pub const Value = nux.Input.Key.e;
				};
				pub const F = struct {
					pub const Name = "F";
					pub const Value = nux.Input.Key.f;
				};
				pub const G = struct {
					pub const Name = "G";
					pub const Value = nux.Input.Key.g;
				};
				pub const H = struct {
					pub const Name = "H";
					pub const Value = nux.Input.Key.h;
				};
				pub const I = struct {
					pub const Name = "I";
					pub const Value = nux.Input.Key.i;
				};
				pub const J = struct {
					pub const Name = "J";
					pub const Value = nux.Input.Key.j;
				};
				pub const K = struct {
					pub const Name = "K";
					pub const Value = nux.Input.Key.k;
				};
				pub const L = struct {
					pub const Name = "L";
					pub const Value = nux.Input.Key.l;
				};
				pub const M = struct {
					pub const Name = "M";
					pub const Value = nux.Input.Key.m;
				};
				pub const N = struct {
					pub const Name = "N";
					pub const Value = nux.Input.Key.n;
				};
				pub const O = struct {
					pub const Name = "O";
					pub const Value = nux.Input.Key.o;
				};
				pub const P = struct {
					pub const Name = "P";
					pub const Value = nux.Input.Key.p;
				};
				pub const Q = struct {
					pub const Name = "Q";
					pub const Value = nux.Input.Key.q;
				};
				pub const R = struct {
					pub const Name = "R";
					pub const Value = nux.Input.Key.r;
				};
				pub const S = struct {
					pub const Name = "S";
					pub const Value = nux.Input.Key.s;
				};
				pub const T = struct {
					pub const Name = "T";
					pub const Value = nux.Input.Key.t;
				};
				pub const U = struct {
					pub const Name = "U";
					pub const Value = nux.Input.Key.u;
				};
				pub const V = struct {
					pub const Name = "V";
					pub const Value = nux.Input.Key.v;
				};
				pub const W = struct {
					pub const Name = "W";
					pub const Value = nux.Input.Key.w;
				};
				pub const X = struct {
					pub const Name = "X";
					pub const Value = nux.Input.Key.x;
				};
				pub const Y = struct {
					pub const Name = "Y";
					pub const Value = nux.Input.Key.y;
				};
				pub const Z = struct {
					pub const Name = "Z";
					pub const Value = nux.Input.Key.z;
				};
				pub const LEFT_BRACKET = struct {
					pub const Name = "LEFT_BRACKET";
					pub const Value = nux.Input.Key.left_bracket;
				};
				pub const BACKSLASH = struct {
					pub const Name = "BACKSLASH";
					pub const Value = nux.Input.Key.backslash;
				};
				pub const RIGHT_BRACKET = struct {
					pub const Name = "RIGHT_BRACKET";
					pub const Value = nux.Input.Key.right_bracket;
				};
				pub const GRAVE_ACCENT = struct {
					pub const Name = "GRAVE_ACCENT";
					pub const Value = nux.Input.Key.grave_accent;
				};
				pub const ESCAPE = struct {
					pub const Name = "ESCAPE";
					pub const Value = nux.Input.Key.escape;
				};
				pub const ENTER = struct {
					pub const Name = "ENTER";
					pub const Value = nux.Input.Key.enter;
				};
				pub const TAB = struct {
					pub const Name = "TAB";
					pub const Value = nux.Input.Key.tab;
				};
				pub const BACKSPACE = struct {
					pub const Name = "BACKSPACE";
					pub const Value = nux.Input.Key.backspace;
				};
				pub const INSERT = struct {
					pub const Name = "INSERT";
					pub const Value = nux.Input.Key.insert;
				};
				pub const DELETE = struct {
					pub const Name = "DELETE";
					pub const Value = nux.Input.Key.delete;
				};
				pub const RIGHT = struct {
					pub const Name = "RIGHT";
					pub const Value = nux.Input.Key.right;
				};
				pub const LEFT = struct {
					pub const Name = "LEFT";
					pub const Value = nux.Input.Key.left;
				};
				pub const DOWN = struct {
					pub const Name = "DOWN";
					pub const Value = nux.Input.Key.down;
				};
				pub const UP = struct {
					pub const Name = "UP";
					pub const Value = nux.Input.Key.up;
				};
				pub const PAGE_UP = struct {
					pub const Name = "PAGE_UP";
					pub const Value = nux.Input.Key.page_up;
				};
				pub const PAGE_DOWN = struct {
					pub const Name = "PAGE_DOWN";
					pub const Value = nux.Input.Key.page_down;
				};
				pub const HOME = struct {
					pub const Name = "HOME";
					pub const Value = nux.Input.Key.home;
				};
				pub const END = struct {
					pub const Name = "END";
					pub const Value = nux.Input.Key.end;
				};
				pub const CAPS_LOCK = struct {
					pub const Name = "CAPS_LOCK";
					pub const Value = nux.Input.Key.caps_lock;
				};
				pub const SCROLL_LOCK = struct {
					pub const Name = "SCROLL_LOCK";
					pub const Value = nux.Input.Key.scroll_lock;
				};
				pub const NUM_LOCK = struct {
					pub const Name = "NUM_LOCK";
					pub const Value = nux.Input.Key.num_lock;
				};
				pub const PRINT_SCREEN = struct {
					pub const Name = "PRINT_SCREEN";
					pub const Value = nux.Input.Key.print_screen;
				};
				pub const PAUSE = struct {
					pub const Name = "PAUSE";
					pub const Value = nux.Input.Key.pause;
				};
				pub const F1 = struct {
					pub const Name = "F1";
					pub const Value = nux.Input.Key.f1;
				};
				pub const F2 = struct {
					pub const Name = "F2";
					pub const Value = nux.Input.Key.f2;
				};
				pub const F3 = struct {
					pub const Name = "F3";
					pub const Value = nux.Input.Key.f3;
				};
				pub const F4 = struct {
					pub const Name = "F4";
					pub const Value = nux.Input.Key.f4;
				};
				pub const F5 = struct {
					pub const Name = "F5";
					pub const Value = nux.Input.Key.f5;
				};
				pub const F6 = struct {
					pub const Name = "F6";
					pub const Value = nux.Input.Key.f6;
				};
				pub const F7 = struct {
					pub const Name = "F7";
					pub const Value = nux.Input.Key.f7;
				};
				pub const F8 = struct {
					pub const Name = "F8";
					pub const Value = nux.Input.Key.f8;
				};
				pub const F9 = struct {
					pub const Name = "F9";
					pub const Value = nux.Input.Key.f9;
				};
				pub const F10 = struct {
					pub const Name = "F10";
					pub const Value = nux.Input.Key.f10;
				};
				pub const F11 = struct {
					pub const Name = "F11";
					pub const Value = nux.Input.Key.f11;
				};
				pub const F12 = struct {
					pub const Name = "F12";
					pub const Value = nux.Input.Key.f12;
				};
				pub const F13 = struct {
					pub const Name = "F13";
					pub const Value = nux.Input.Key.f13;
				};
				pub const F14 = struct {
					pub const Name = "F14";
					pub const Value = nux.Input.Key.f14;
				};
				pub const F15 = struct {
					pub const Name = "F15";
					pub const Value = nux.Input.Key.f15;
				};
				pub const F16 = struct {
					pub const Name = "F16";
					pub const Value = nux.Input.Key.f16;
				};
				pub const F17 = struct {
					pub const Name = "F17";
					pub const Value = nux.Input.Key.f17;
				};
				pub const F18 = struct {
					pub const Name = "F18";
					pub const Value = nux.Input.Key.f18;
				};
				pub const F19 = struct {
					pub const Name = "F19";
					pub const Value = nux.Input.Key.f19;
				};
				pub const F20 = struct {
					pub const Name = "F20";
					pub const Value = nux.Input.Key.f20;
				};
				pub const F21 = struct {
					pub const Name = "F21";
					pub const Value = nux.Input.Key.f21;
				};
				pub const F22 = struct {
					pub const Name = "F22";
					pub const Value = nux.Input.Key.f22;
				};
				pub const F23 = struct {
					pub const Name = "F23";
					pub const Value = nux.Input.Key.f23;
				};
				pub const F24 = struct {
					pub const Name = "F24";
					pub const Value = nux.Input.Key.f24;
				};
				pub const F25 = struct {
					pub const Name = "F25";
					pub const Value = nux.Input.Key.f25;
				};
				pub const KP_0 = struct {
					pub const Name = "KP_0";
					pub const Value = nux.Input.Key.kp_0;
				};
				pub const KP_1 = struct {
					pub const Name = "KP_1";
					pub const Value = nux.Input.Key.kp_1;
				};
				pub const KP_2 = struct {
					pub const Name = "KP_2";
					pub const Value = nux.Input.Key.kp_2;
				};
				pub const KP_3 = struct {
					pub const Name = "KP_3";
					pub const Value = nux.Input.Key.kp_3;
				};
				pub const KP_4 = struct {
					pub const Name = "KP_4";
					pub const Value = nux.Input.Key.kp_4;
				};
				pub const KP_5 = struct {
					pub const Name = "KP_5";
					pub const Value = nux.Input.Key.kp_5;
				};
				pub const KP_6 = struct {
					pub const Name = "KP_6";
					pub const Value = nux.Input.Key.kp_6;
				};
				pub const KP_7 = struct {
					pub const Name = "KP_7";
					pub const Value = nux.Input.Key.kp_7;
				};
				pub const KP_8 = struct {
					pub const Name = "KP_8";
					pub const Value = nux.Input.Key.kp_8;
				};
				pub const KP_9 = struct {
					pub const Name = "KP_9";
					pub const Value = nux.Input.Key.kp_9;
				};
				pub const KP_DECIMAL = struct {
					pub const Name = "KP_DECIMAL";
					pub const Value = nux.Input.Key.kp_decimal;
				};
				pub const KP_DIVIDE = struct {
					pub const Name = "KP_DIVIDE";
					pub const Value = nux.Input.Key.kp_divide;
				};
				pub const KP_MULTIPLY = struct {
					pub const Name = "KP_MULTIPLY";
					pub const Value = nux.Input.Key.kp_multiply;
				};
				pub const KP_SUBTRACT = struct {
					pub const Name = "KP_SUBTRACT";
					pub const Value = nux.Input.Key.kp_subtract;
				};
				pub const KP_ADD = struct {
					pub const Name = "KP_ADD";
					pub const Value = nux.Input.Key.kp_add;
				};
				pub const KP_ENTER = struct {
					pub const Name = "KP_ENTER";
					pub const Value = nux.Input.Key.kp_enter;
				};
				pub const KP_EQUAL = struct {
					pub const Name = "KP_EQUAL";
					pub const Value = nux.Input.Key.kp_equal;
				};
				pub const LEFT_SHIFT = struct {
					pub const Name = "LEFT_SHIFT";
					pub const Value = nux.Input.Key.left_shift;
				};
				pub const LEFT_CONTROL = struct {
					pub const Name = "LEFT_CONTROL";
					pub const Value = nux.Input.Key.left_control;
				};
				pub const LEFT_ALT = struct {
					pub const Name = "LEFT_ALT";
					pub const Value = nux.Input.Key.left_alt;
				};
				pub const LEFT_SUPER = struct {
					pub const Name = "LEFT_SUPER";
					pub const Value = nux.Input.Key.left_super;
				};
				pub const RIGHT_SHIFT = struct {
					pub const Name = "RIGHT_SHIFT";
					pub const Value = nux.Input.Key.right_shift;
				};
				pub const RIGHT_CONTROL = struct {
					pub const Name = "RIGHT_CONTROL";
					pub const Value = nux.Input.Key.right_control;
				};
				pub const RIGHT_ALT = struct {
					pub const Name = "RIGHT_ALT";
					pub const Value = nux.Input.Key.right_alt;
				};
				pub const RIGHT_SUPER = struct {
					pub const Name = "RIGHT_SUPER";
					pub const Value = nux.Input.Key.right_super;
				};
				pub const MENU = struct {
					pub const Name = "MENU";
					pub const Value = nux.Input.Key.menu;
				};
			};
		};
		pub const State = struct {
			pub const Name = "State";
			pub const is_bitfield = false;
			pub const Values = struct {
				pub const PRESSED = struct {
					pub const Name = "PRESSED";
					pub const Value = nux.Input.State.pressed;
				};
				pub const RELEASED = struct {
					pub const Name = "RELEASED";
					pub const Value = nux.Input.State.released;
				};
			};
		};
	};
	pub const Functions = struct {
		pub const isPressed = struct {
			pub const Name = "isPressed";
			pub const Function = nux.Input.isPressed;
		};
		pub const isReleased = struct {
			pub const Name = "isReleased";
			pub const Function = nux.Input.isReleased;
		};
		pub const isJustPressed = struct {
			pub const Name = "isJustPressed";
			pub const Function = nux.Input.isJustPressed;
		};
		pub const isJustReleased = struct {
			pub const Name = "isJustReleased";
			pub const Function = nux.Input.isJustReleased;
		};
	};
	pub const Properties = struct {
	};
};
pub const InputMap = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const bindKey = struct {
			pub const Name = "bindKey";
			pub const Function = nux.InputMap.bindKey;
		};
	};
	pub const Properties = struct {
	};
};
pub const Texture = struct {
	pub const Enums = struct {
		pub const Type = struct {
			pub const Name = "Type";
			pub const is_bitfield = false;
			pub const Values = struct {
				pub const IMAGE_RGBA = struct {
					pub const Name = "IMAGE_RGBA";
					pub const Value = nux.Texture.Type.image_rgba;
				};
				pub const IMAGE_INDEXED = struct {
					pub const Name = "IMAGE_INDEXED";
					pub const Value = nux.Texture.Type.image_indexed;
				};
				pub const RENDER_TARGET = struct {
					pub const Name = "RENDER_TARGET";
					pub const Value = nux.Texture.Type.render_target;
				};
			};
		};
		pub const Filtering = struct {
			pub const Name = "Filtering";
			pub const is_bitfield = false;
			pub const Values = struct {
				pub const NEAREST = struct {
					pub const Name = "NEAREST";
					pub const Value = nux.Texture.Filtering.nearest;
				};
				pub const LINEAR = struct {
					pub const Name = "LINEAR";
					pub const Value = nux.Texture.Filtering.linear;
				};
			};
		};
	};
	pub const Functions = struct {
		pub const addFromData = struct {
			pub const Name = "addFromData";
			pub const Function = nux.Texture.addFromData;
		};
		pub const blit = struct {
			pub const Name = "blit";
			pub const Function = nux.Texture.blit;
		};
		pub const addFromFile = struct {
			pub const Name = "addFromFile";
			pub const Function = nux.Texture.addFromFile;
		};
		pub const addTransparent = struct {
			pub const Name = "addTransparent";
			pub const Function = nux.Texture.addTransparent;
		};
	};
	pub const Properties = struct {
	};
};
pub const Material = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
	};
	pub const Properties = struct {
	};
};
pub const Mesh = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const resize = struct {
			pub const Name = "resize";
			pub const Function = nux.Mesh.resize;
		};
	};
	pub const Properties = struct {
	};
};
pub const Gltf = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const loadGltf = struct {
			pub const Name = "loadGltf";
			pub const Function = nux.Gltf.loadGltf;
		};
	};
	pub const Properties = struct {
	};
};
pub const Vertex = struct {
	pub const Enums = struct {
		pub const Attributes = struct {
			pub const Name = "Attributes";
			pub const is_bitfield = true;
			pub const Values = struct {
				pub const POSITION = struct {
					pub const Name = "POSITION";
					pub const Value = nux.Vertex.Attributes.position;
				};
				pub const TEXCOORD = struct {
					pub const Name = "TEXCOORD";
					pub const Value = nux.Vertex.Attributes.texcoord;
				};
				pub const COLOR = struct {
					pub const Name = "COLOR";
					pub const Value = nux.Vertex.Attributes.color;
				};
				pub const NORMAL = struct {
					pub const Name = "NORMAL";
					pub const Value = nux.Vertex.Attributes.normal;
				};
			};
		};
		pub const Primitive = struct {
			pub const Name = "Primitive";
			pub const is_bitfield = false;
			pub const Values = struct {
				pub const TRIANGLES = struct {
					pub const Name = "TRIANGLES";
					pub const Value = nux.Vertex.Primitive.triangles;
				};
				pub const LINES = struct {
					pub const Name = "LINES";
					pub const Value = nux.Vertex.Primitive.lines;
				};
				pub const POINTS = struct {
					pub const Name = "POINTS";
					pub const Value = nux.Vertex.Primitive.points;
				};
			};
		};
	};
	pub const Functions = struct {
	};
	pub const Properties = struct {
	};
};
pub const StaticMesh = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const setTexture = struct {
			pub const Name = "setTexture";
			pub const Function = nux.StaticMesh.setTexture;
		};
		pub const getMesh = struct {
			pub const Name = "getMesh";
			pub const Function = nux.StaticMesh.getMesh;
		};
		pub const setTransform = struct {
			pub const Name = "setTransform";
			pub const Function = nux.StaticMesh.setTransform;
		};
		pub const setMesh = struct {
			pub const Name = "setMesh";
			pub const Function = nux.StaticMesh.setMesh;
		};
		pub const getTexture = struct {
			pub const Name = "getTexture";
			pub const Function = nux.StaticMesh.getTexture;
		};
		pub const getTransform = struct {
			pub const Name = "getTransform";
			pub const Function = nux.StaticMesh.getTransform;
		};
	};
	pub const Properties = struct {
		pub const Texture = struct {
			pub const Name = StaticMesh.Functions.getTexture.Name[3..];
			pub const Getter = nux.StaticMesh.getTexture;
			pub const Setter = nux.StaticMesh.setTexture;
		};
		pub const Mesh = struct {
			pub const Name = StaticMesh.Functions.getMesh.Name[3..];
			pub const Getter = nux.StaticMesh.getMesh;
			pub const Setter = nux.StaticMesh.setMesh;
		};
		pub const Transform = struct {
			pub const Name = StaticMesh.Functions.getTransform.Name[3..];
			pub const Getter = nux.StaticMesh.getTransform;
			pub const Setter = nux.StaticMesh.setTransform;
		};
	};
};
pub const Viewport = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const setWidget = struct {
			pub const Name = "setWidget";
			pub const Function = nux.Viewport.setWidget;
		};
		pub const setCamera = struct {
			pub const Name = "setCamera";
			pub const Function = nux.Viewport.setCamera;
		};
	};
	pub const Properties = struct {
		pub const Widget = struct {
			pub const Setter = nux.Viewport.setWidget;
		};
		pub const Camera = struct {
			pub const Setter = nux.Viewport.setCamera;
		};
	};
};
pub const Widget = struct {
	pub const Enums = struct {
		pub const Direction = struct {
			pub const Name = "Direction";
			pub const is_bitfield = false;
			pub const Values = struct {
				pub const LEFT_TO_RIGHT = struct {
					pub const Name = "LEFT_TO_RIGHT";
					pub const Value = nux.Widget.Direction.left_to_right;
				};
				pub const TOP_TO_BOTTOM = struct {
					pub const Name = "TOP_TO_BOTTOM";
					pub const Value = nux.Widget.Direction.top_to_bottom;
				};
			};
		};
		pub const AlignmentY = struct {
			pub const Name = "AlignmentY";
			pub const is_bitfield = false;
			pub const Values = struct {
				pub const TOP = struct {
					pub const Name = "TOP";
					pub const Value = nux.Widget.AlignmentY.top;
				};
				pub const BOTTOM = struct {
					pub const Name = "BOTTOM";
					pub const Value = nux.Widget.AlignmentY.bottom;
				};
				pub const CENTER = struct {
					pub const Name = "CENTER";
					pub const Value = nux.Widget.AlignmentY.center;
				};
			};
		};
		pub const Sizing = struct {
			pub const Name = "Sizing";
			pub const is_bitfield = false;
			pub const Values = struct {
				pub const FIT = struct {
					pub const Name = "FIT";
					pub const Value = nux.Widget.Sizing.fit;
				};
				pub const GROW = struct {
					pub const Name = "GROW";
					pub const Value = nux.Widget.Sizing.grow;
				};
				pub const PERCENT = struct {
					pub const Name = "PERCENT";
					pub const Value = nux.Widget.Sizing.percent;
				};
				pub const FIXED = struct {
					pub const Name = "FIXED";
					pub const Value = nux.Widget.Sizing.fixed;
				};
			};
		};
		pub const AlignmentX = struct {
			pub const Name = "AlignmentX";
			pub const is_bitfield = false;
			pub const Values = struct {
				pub const LEFT = struct {
					pub const Name = "LEFT";
					pub const Value = nux.Widget.AlignmentX.left;
				};
				pub const RIGHT = struct {
					pub const Name = "RIGHT";
					pub const Value = nux.Widget.AlignmentX.right;
				};
				pub const CENTER = struct {
					pub const Name = "CENTER";
					pub const Value = nux.Widget.AlignmentX.center;
				};
			};
		};
	};
	pub const Functions = struct {
		pub const setAlignX = struct {
			pub const Name = "setAlignX";
			pub const Function = nux.Widget.setAlignX;
		};
		pub const setPadding = struct {
			pub const Name = "setPadding";
			pub const Function = nux.Widget.setPadding;
		};
		pub const setSizeY = struct {
			pub const Name = "setSizeY";
			pub const Function = nux.Widget.setSizeY;
		};
		pub const setBorder = struct {
			pub const Name = "setBorder";
			pub const Function = nux.Widget.setBorder;
		};
		pub const setAlignY = struct {
			pub const Name = "setAlignY";
			pub const Function = nux.Widget.setAlignY;
		};
		pub const setDirection = struct {
			pub const Name = "setDirection";
			pub const Function = nux.Widget.setDirection;
		};
		pub const setBackgroundColor = struct {
			pub const Name = "setBackgroundColor";
			pub const Function = nux.Widget.setBackgroundColor;
		};
		pub const setBorderRadius = struct {
			pub const Name = "setBorderRadius";
			pub const Function = nux.Widget.setBorderRadius;
		};
		pub const setChildGap = struct {
			pub const Name = "setChildGap";
			pub const Function = nux.Widget.setChildGap;
		};
		pub const setSizeX = struct {
			pub const Name = "setSizeX";
			pub const Function = nux.Widget.setSizeX;
		};
		pub const setBorderColor = struct {
			pub const Name = "setBorderColor";
			pub const Function = nux.Widget.setBorderColor;
		};
	};
	pub const Properties = struct {
		pub const AlignY = struct {
			pub const Setter = nux.Widget.setAlignY;
		};
		pub const Direction = struct {
			pub const Setter = nux.Widget.setDirection;
		};
		pub const BorderRadius = struct {
			pub const Setter = nux.Widget.setBorderRadius;
		};
		pub const ChildGap = struct {
			pub const Setter = nux.Widget.setChildGap;
		};
		pub const AlignX = struct {
			pub const Setter = nux.Widget.setAlignX;
		};
		pub const SizeX = struct {
			pub const Setter = nux.Widget.setSizeX;
		};
		pub const BorderColor = struct {
			pub const Setter = nux.Widget.setBorderColor;
		};
		pub const Border = struct {
			pub const Setter = nux.Widget.setBorder;
		};
		pub const BackgroundColor = struct {
			pub const Setter = nux.Widget.setBackgroundColor;
		};
		pub const Padding = struct {
			pub const Setter = nux.Widget.setPadding;
		};
		pub const SizeY = struct {
			pub const Setter = nux.Widget.setSizeY;
		};
	};
};
pub const Button = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const click = struct {
			pub const Name = "click";
			pub const Function = nux.Button.click;
		};
	};
	pub const Properties = struct {
	};
};
pub const Label = struct {
	pub const Enums = struct {
	};
	pub const Functions = struct {
		pub const setColor = struct {
			pub const Name = "setColor";
			pub const Function = nux.Label.setColor;
		};
		pub const setText = struct {
			pub const Name = "setText";
			pub const Function = nux.Label.setText;
		};
	};
	pub const Properties = struct {
		pub const Text = struct {
			pub const Setter = nux.Label.setText;
		};
		pub const Color = struct {
			pub const Setter = nux.Label.setColor;
		};
	};
};
