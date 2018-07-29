module sand.api;
import sand.sane;
import sand.saneopts;

import std.exception : enforce, assertThrown;
import std.algorithm.iteration, std.string;
import std.conv, std.range, std.utf;
import std.algorithm: canFind;
import std.algorithm.searching: find;
import std.stdio;
import std.traits;

/** The D interface to SANE */
class Sane {
    int versionMajor, versionMinor, versionBuild;
    Device[] m_devices;

    this() {
        init();
    }

    ~this() {
        sane_exit();
    }

    private void init() {
        int api_version;
        auto status = sane_init(&api_version, null);
        enforce(status == SANE_Status.SANE_STATUS_GOOD);
        SANE_VERSION_CODE(versionMajor, versionMinor, versionBuild);
    }

    /**
     * Get list of devices connected to this machine
     * Params:
     *   force = recheck all devices
     */
    auto devices(bool force=false) {
        if(!m_devices.length || force) {
            SANE_Device** device_list;
            auto status = sane_get_devices(&device_list, true);
            auto size = 0;
            while(*(device_list + size))
                size++;
            m_devices =  device_list[0 .. size].map!(device => new Device(device)).array;
        }
        return m_devices;
    }
}

enum Format {
    GREY = 0,
    RGB = 1,
    RED = 2,
    GREEN = 3,
    BLUE = 4
}

struct Parameters {
    Format frame;
    bool lastFrame;
    uint bytesPerLine;
    uint pixelsPerLine;
    uint lines;
    uint bitdepth;
}

class Device {
    string name;
    string vendor;
    string model;
    string type;
    SANE_Device* device;
    private Option[] m_options;
    private SANE_Handle handle;
    private bool open;

    this(SANE_Device* device) {
        name = to!string((*device).name);
        vendor = to!string((*device).vendor);
        model = to!string((*device).model);
        type = to!string((*device).type);
        this.device = device;
        sane_open(device.name, &handle);
    }

    override string toString() {
        return format("SANE Device: %s - %s", vendor, model);
    }

    /** Get options */
    @property auto options() {
        if(!open) {
            populateOptions();
            open = true;
        }
        return m_options;
    }

    /** Get current scan parameters */
    @property Parameters parameters() {
        SANE_Parameters p;
        sane_get_parameters(handle, &p);
        auto parameters = Parameters(cast(Format)p.format,
                                     cast(bool)p.last_frame,
                                     p.bytes_per_line,
                                     p.pixels_per_line,
                                     p.lines,
                                     p.depth);
        return parameters;
    }

    private void populateOptions() {
        auto size = 0;
        while(sane_get_option_descriptor(handle, size))
            size++;
        m_options = iota(size).map!(i => new Option(handle, i)).array;
    }

    /** 
     * Blocking operation!
     * Returns: A new buffer with image data
     */
    auto readImage() {
        sane_start(handle);
        SANE_Parameters params;
        enforce(sane_get_parameters(handle, &params) == SANE_Status.SANE_STATUS_GOOD);
        auto totalBytes = params.lines * params.bytes_per_line;
        ubyte[] data = new ubyte[totalBytes];
        int length, offset;
        SANE_Status status;
        do {
            ubyte* ptr = data.ptr + offset;
            status = sane_read(handle, ptr, totalBytes, &length);
            offset += length;
        } while (status == SANE_Status.SANE_STATUS_GOOD);
        return data;
    }
}

enum ValueType {
    BOOL = 0,
    GROUP = 1,
    INT = 2,
    FIXED = 3,
    STRING = 4,
    BUTTON = 5
}

enum ConstraintType {
    NONE = 0,
    RANGE = 1,
    WORD_LIST = 2,
    STRING_LIST = 3
}

class Option {
    int number;
    const string name;
    const string title;
    const string description;
    const string unit;
    private SANE_Handle handle;

    this(SANE_Handle handle, int number) {
        this.number = number;
        auto descriptor = sane_get_option_descriptor(handle, number);
        name = to!string((*descriptor).name);
        title = to!string((*descriptor).title);
        description = to!string((*descriptor).desc);
        unit = unitToString(descriptor.unit);
        this.handle = handle;
    }

    override string toString() {
        return format("Option:\nName: %s\nTitle: %s\nDescription: %s\nUnit: %s" ~
                      "\nSettable: %s\nActive: %s", name, title, description, unit, settable(), active());
    }

    private string unitToString(SANE_Unit unit) {
        switch(unit) {
        case SANE_Unit.SANE_UNIT_NONE:
            return "(none)";
        case SANE_Unit.SANE_UNIT_PIXEL:
            return "pixels";
        case SANE_Unit.SANE_UNIT_BIT:
            return "bits";
        case SANE_Unit.SANE_UNIT_MM:
            return "millimetres";
        case SANE_Unit.SANE_UNIT_DPI:
            return "dots per inch";
        case SANE_Unit.SANE_UNIT_PERCENT:
            return "percentage";
        case SANE_Unit.SANE_UNIT_MICROSECOND:
            return "microseconds";
        default:
            assert(0);
        }
    }

    @property const(bool) settable() {
        return SANE_OPTION_IS_SETTABLE(sane_get_option_descriptor(handle, number).cap);
    }

    @property const(bool) active() {
        return SANE_OPTION_IS_ACTIVE(sane_get_option_descriptor(handle, number).cap);
    }

    @property const(bool) group() {
        return type() == ValueType.GROUP;
    }

    @property const(ValueType) type() {
        auto type = sane_get_option_descriptor(handle, number).type;
        switch(type) {
        case SANE_Value_Type.SANE_TYPE_BOOL:
            return ValueType.BOOL;
        case SANE_Value_Type.SANE_TYPE_GROUP:
            return ValueType.GROUP;
        case SANE_Value_Type.SANE_TYPE_INT:
            return ValueType.INT;
        case SANE_Value_Type.SANE_TYPE_FIXED:
            return ValueType.FIXED;
        case SANE_Value_Type.SANE_TYPE_STRING:
            return ValueType.STRING;
        case SANE_Value_Type.SANE_TYPE_BUTTON:
            return ValueType.BUTTON;
        default:
	    throw new Exception("Unknown Type");
        }
    }

    @property const(T) max(T)() {
        static if(is(T == double)) {
            return SANE_UNFIX(sane_get_option_descriptor(handle, number).constraint.range.max);
        } else {
            return sane_get_option_descriptor(handle, number).constraint.range.max;
        }
    }

    @property const(T) min(T)() {
        static if(is(T == double)) {
            return SANE_UNFIX(sane_get_option_descriptor(handle, number).constraint.range.min);
        } else {
            return sane_get_option_descriptor(handle, number).constraint.range.min;
        }
    }

    @property const(T) quant(T)() {
        static if(is(T == double)) {
            return SANE_UNFIX(sane_get_option_descriptor(handle, number).constraint.range.quant);
        } else {
            return sane_get_option_descriptor(handle, number).constraint.range.quant;
        }
    }

    @property const(T) value(T)() {
        auto descriptor = sane_get_option_descriptor(handle, number);
        char[] space = new char[descriptor.size];
        auto status = sane_control_option(handle, number, SANE_Action.SANE_ACTION_GET_VALUE, space.ptr, null);
        enforce(status == SANE_Status.SANE_STATUS_GOOD);
        static if(is(T == string)) {
            return to!string(cast(char*)(space));
        } else static if(is(T == double)) {
            return SANE_UNFIX(*(cast(SANE_Fixed*)(space.ptr)));
        }
        else static if(isPointer!T) {
            return cast(T)(space.ptr);
        } else {
            auto value = cast(T*)(space.ptr);
            return *value;
        }
    }

    /**
     * Set property value
     */
    @property void value(T)(T value) {
        if(!settable())
            throw new Exception("Option is not settable");
        if(!meetsConstraint(value))
            throw new Exception("Value doesn't meet constriant");
        auto descriptor = sane_get_option_descriptor(handle, number);
        static if(is(T == string)) {
            auto v = cast(char*)value.toStringz();
            auto status = sane_control_option(handle, number, SANE_Action.SANE_ACTION_SET_VALUE, v, null);
            enforce(status == SANE_Status.SANE_STATUS_GOOD);
        } else static if(is(T == double)) {
            auto v = SANE_FIX(value);
            auto status = sane_control_option(handle, number, SANE_Action.SANE_ACTION_SET_VALUE, &v, null);
            enforce(status == SANE_Status.SANE_STATUS_GOOD);
        } else static if(is(T == bool)) {
            auto v = cast(int)value;
            auto status = sane_control_option(handle, number, SANE_Action.SANE_ACTION_SET_VALUE, &v, null);
            enforce(status == SANE_Status.SANE_STATUS_GOOD);
        }
        else {
            auto status = sane_control_option(handle, number, SANE_Action.SANE_ACTION_SET_VALUE, &value, null);
            enforce(status == SANE_Status.SANE_STATUS_GOOD);
        }
    }

    @property const(char*)[] strings() {
        const(char*)[] stringList;
        auto descriptor = sane_get_option_descriptor(handle, number);
        switch(descriptor.constraint_type) {            
        case SANE_Constraint_Type.SANE_CONSTRAINT_STRING_LIST:
            int position = 0;
            while(*(descriptor.constraint.string_list + position)) {
                stringList ~= *(descriptor.constraint.string_list + position);
                position++;
            }
            break;
        default:
            assert(0);
        }
        return stringList;
    }

    @property const(int)[] words() {
        auto descriptor = sane_get_option_descriptor(handle, number);
        int length = *(descriptor.constraint.word_list);
        return descriptor.constraint.word_list[1..length + 1].array;
    }

    @property ConstraintType constraintType() {
        auto descriptor = sane_get_option_descriptor(handle, number);
        return cast(ConstraintType)descriptor.constraint_type;
    }

    private bool meetsConstraint(T)(T value) {
        auto descriptor = sane_get_option_descriptor(handle, number);
        switch(descriptor.constraint_type) {            
        case SANE_Constraint_Type.SANE_CONSTRAINT_NONE:
            return true;
        case SANE_Constraint_Type.SANE_CONSTRAINT_RANGE:
            auto range = descriptor.constraint.range;
            // if(range.quant != 0) {
            //     if(value < range.min || value > range.max)
            //         return false;
            //     if((range.quant * value + range.min) <= range.max)
            //         return true;
            //     return false;
            // }
            return true;
        case SANE_Constraint_Type.SANE_CONSTRAINT_WORD_LIST:
            auto count = *descriptor.constraint.word_list;
            auto wordList = descriptor.constraint.word_list[1..count + 1];
            return wordList.canFind(value);
        default:
            throw new Exception("Value doesn't meet constraint");
        }
    }

    private bool meetsConstraint(string value) {
        auto descriptor = sane_get_option_descriptor(handle, number);
        switch(descriptor.constraint_type) {            
        case SANE_Constraint_Type.SANE_CONSTRAINT_STRING_LIST:
            string[] stringList;
            int position = 0;
            while(*(descriptor.constraint.string_list + position)) {
                stringList ~= to!string(*(descriptor.constraint.string_list + position));
                position++;
            }
            return stringList.canFind(value);
        default:
            throw new Exception("Can't enfore constraint");
        }
    }
}

unittest {
    auto s = new Sane();
    auto devices = s.devices();
    assert(devices[0].options[3].value!int == 8);
    devices[0].options[3].value = 16;
    assert(devices[0].options[3].value!int == 16);
    assert(devices[0].options[3].settable);
    assert(devices[0].options[3].active);

    assert(devices[0].options[2].value!string == "Gray");
    devices[0].options[2].value!string = "Gray";
    assertThrown(devices[0].options[2].value = "Grey");
    devices[0].readImage();
    assertThrown(devices[0].options[0].value = 5);
    assert(devices[0].options[1].group);
    assert(!devices[0].options[2].group);
}
