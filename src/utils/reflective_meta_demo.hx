import haxe.vm.*;

class ReflectiveMetaProgrammingDemo {
    static function main() {
        var classes = [Type.resolveClass("MyClassA"), Type.resolveClass("MyClassB"), Type.resolveClass("MyClassC")];
        for (cls in classes) {
            if (cls != null) {
                trace("Processing class: " + Type.getClassName(cls));
                var fields = Type.getInstanceFields(cls);
                for (field in fields) {
                    var fieldType = Type.getInstanceFieldType(cls, field);
                    var isStatic = Type.getInstanceFieldAccess(cls, field) == "static";
                    var value;
                    if (isStatic) {
                        value = Reflect.field(cls, field);
                    } else {
                        var instance = Type.createInstance(cls, []);
                        value = Reflect.field(instance, field);
                        handleField(instance, field, value);
                        reflectOnType(instance);
                    }
                    trace("Field: " + field + " Type: " + fieldType + " Static: " + isStatic + " Value: " + Std.string(value));
                }
                processMethods(cls);
            }
        }
        var dynamicObj = createDynamicObject();
        dynamicOperation(dynamicObj);
        var metaDataObj = createMetaDataObject();
        extendObject(metaDataObj);
    }

    static function handleField(instance:Dynamic, name:String, value:Dynamic) {
        if (Std.is(value, Int)) {
            Reflect.setField(instance, name, value + 1);
        } else if (Std.is(value, String)) {
            Reflect.setField(instance, name, value + "_modified");
        }
    }

    static function reflectOnType(obj:Dynamic) {
        var classInfo = Type.getClass(obj);
        var fields = Type.getInstanceFields(classInfo);
        for (field in fields) {
            var val = Reflect.field(obj, field);
            var fieldType = Type.getInstanceFieldType(classInfo, field);
            if (Std.is(val, Dynamic)) {
                handleNestedObject(val);
            }
        }
    }

    static function handleNestedObject(nested:Dynamic) {
        var nestedFields = Type.getInstanceFields(Type.getClass(nested));
        for (nfield in nestedFields) {
            var nval = Reflect.field(nested, nfield);
            if (Std.is(nval, Int)) {
                Reflect.setField(nested, nfield, nval * 2);
            }
        }
    }

    static function processMethods(cls:Class<Dynamic>) {
        var methods = Type.getInstanceFields(cls);
        for (methodName in methods) {
            var methodType = Type.getInstanceMethodType(cls, methodName);
            if (methodType != null && methodType.args.length > 0) {
                var method = Reflect.field(cls, methodName);
                if (Std.is(method, Function)) {
                    var args = generateArguments(methodType.args);
                    var result = Reflect.callMethod(cls, Reflect.field(cls, methodName), args);
                    trace("Called method: " + methodName + " Result: " + Std.string(result));
                }
            }
        }
    }

    static function generateArguments(types:Array<Type>):Array<Dynamic> {
        var args = [];
        for (t in types) {
            switch (t) {
                case Type.getInt():
                    args.push(42);
                case Type.getString():
                    args.push("test");
                case Type.getFloat():
                    args.push(3.14);
                default:
                    args.push(null);
            }
        }
        return args;
    }

    static function createDynamicObject():Dynamic {
        var obj = {};
        obj["name"] = "DynamicObject";
        obj["value"] = 100;
        obj["doAction"] = function() return "Action executed";
        return obj;
    }

    static function dynamicOperation(dyn:Dynamic):Void {
        if (Reflect.hasField(dyn, "doAction")) {
            var result = Reflect.callMethod(dyn, dyn["doAction"], []);
            trace("Dynamic operation result: " + result);
        }
        dyn["newField"] = "Added dynamically";
    }

    static function createMetaDataObject():Dynamic {
        var metaObj = {meta:"data", timestamp:Date.now()};
        metaObj["nested"] = {info:"nested data", count:5};
        return metaObj;
    }

    static function extendObject(obj:Dynamic):Void {
        Reflect.setField(obj, "extended", true);
        if (Reflect.hasField(obj, "nested")) {
            var nested = Reflect.field(obj, "nested");
            nested["additional"] = "extra info";
        }
    }
}

class MyClassA {
    public var x:Int;
    public var name:String;
    public function new() {
        x = 10;
        name = "A";
    }
    public function greet():String {
        return "Hello from A";
    }
    public static function staticMethodA(param:String):String {
        return "Static A: " + param;
    }
}

class MyClassB {
    public var y:Float;
    public var description:String;
    public function new() {
        y = 5.5;
        description = "Class B";
    }
    public function compute():Float {
        return y * 2;
    }
    public static function staticMethodB(value:Int):Int {
        return value * 2;
    }
}

class MyClassC {
    public var flag:Bool;
    public var data:Array<Int>;
    public function new() {
        flag = true;
        data = [1,2,3];
    }
    public function toggleFlag():Bool {
        flag = !flag;
        return flag;
    }
    public static function staticMethodC():String {
        return "Static C method";
    }
}