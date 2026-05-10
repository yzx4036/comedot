using System;
using System.Collections;
using System.Globalization;
using System.Linq;
using System.Reflection;
using Godot;
using Y0Studio.Config;

namespace Comedot.Config;

/// <summary>
/// Godot-facing Luban configuration service.
/// It keeps generated C# row objects inside C# and exposes GDScript-safe dictionaries, arrays and scalar values.
/// </summary>
public partial class LubanConfigService : Node
{
    [Export(PropertyHint.Dir)]
    public string ConfigDirectory { get; set; } = ConfigMgr.DefaultConfigDirectory;

    [Export]
    public string ConfigNamespacePrefix { get; set; } = ConfigMgr.DefaultConfigNamespacePrefix;

    [Export]
    public bool LoadOnReady { get; set; } = true;

    public ConfigMgr ConfigMgr { get; private set; }
    public bool IsLoaded => ConfigMgr != null;

    public override void _Ready()
    {
        if (LoadOnReady)
        {
            LoadConfigs();
        }
    }

    public override void _ExitTree()
    {
        UnloadConfigs();
    }

    public bool LoadConfigs()
    {
        if (ConfigMgr != null)
        {
            return true;
        }

        try
        {
            ConfigMgr = new ConfigMgr(ConfigDirectory, ConfigNamespacePrefix);
            GD.Print($"Luban configs loaded: {ConfigMgr.ConfigNames.Count} tables from {ConfigMgr.ConfigDirectory}");
            return true;
        }
        catch (Exception ex)
        {
            GD.PushError($"Luban config load failed. Directory: {ConfigDirectory}. Namespace: {ConfigNamespacePrefix}. Error: {ex.Message}");
            ConfigMgr = null;
            return false;
        }
    }

    public bool ReloadConfigs()
    {
        UnloadConfigs();
        return LoadConfigs();
    }

    public void UnloadConfigs()
    {
        ConfigMgr?.Dispose();
        ConfigMgr = null;
    }

    public Godot.Collections.Array GetConfigNames()
    {
        var result = new Godot.Collections.Array();
        if (!EnsureLoaded())
        {
            return result;
        }

        foreach (var configName in ConfigMgr.ConfigNames.OrderBy(static name => name, StringComparer.OrdinalIgnoreCase))
        {
            result.Add(configName);
        }

        return result;
    }

    public bool HasTable(string configName)
    {
        return EnsureLoaded() && ConfigMgr.TryGetByConfigName(configName, out _);
    }

    public bool HasRecord(string configName, Variant key)
    {
        return TryGetRecordObject(configName, key, out _);
    }

    public Godot.Collections.Dictionary GetRecord(string configName, Variant key)
    {
        if (!TryGetRecordObject(configName, key, out var record))
        {
            return new Godot.Collections.Dictionary();
        }

        return ConvertObjectToDictionary(record);
    }

    public Godot.Collections.Array GetRecords(string configName)
    {
        var result = new Godot.Collections.Array();
        if (!TryGetTable(configName, out var table))
        {
            return result;
        }

        var dataList = GetPropertyValue(table, "DataList") as IEnumerable;
        if (dataList == null)
        {
            GD.PushError($"Luban config table has no DataList: {configName}");
            return result;
        }

        foreach (var record in dataList)
        {
            result.Add(ConvertObjectToDictionary(record));
        }

        return result;
    }

    public Variant GetValue(string configName, Variant key, string fieldName)
    {
        if (!TryGetRecordObject(configName, key, out var record))
        {
            return default;
        }

        if (!TryGetMemberValue(record, fieldName, out var value))
        {
            GD.PushError($"Luban config field not found. Table: {configName}. Field: {fieldName}");
            return default;
        }

        return ConvertObjectToVariant(value);
    }

    private bool EnsureLoaded()
    {
        if (ConfigMgr != null)
        {
            return true;
        }

        GD.PushError("Luban configs are not loaded.");
        return false;
    }

    private bool TryGetTable(string configName, out IConfigSingleton table)
    {
        table = null;
        if (!EnsureLoaded())
        {
            return false;
        }

        if (ConfigMgr.TryGetByConfigName(configName, out table))
        {
            return true;
        }

        GD.PushError($"Luban config table not found: {configName}");
        return false;
    }

    private bool TryGetRecordObject(string configName, Variant key, out object record)
    {
        record = null;
        if (!TryGetTable(configName, out var table))
        {
            return false;
        }

        var dataMap = GetPropertyValue(table, "DataMap") as IDictionary;
        if (dataMap == null)
        {
            GD.PushError($"Luban config table has no DataMap: {configName}");
            return false;
        }

        var keyType = GetDictionaryKeyType(dataMap.GetType());
        var convertedKey = ConvertVariantToKey(key, keyType);
        if (convertedKey == null || !dataMap.Contains(convertedKey))
        {
            GD.PushError($"Luban config record not found. Table: {configName}. Key: {key}");
            return false;
        }

        record = dataMap[convertedKey];
        return record != null;
    }

    private static Type GetDictionaryKeyType(Type dictionaryType)
    {
        var dictionaryInterface = dictionaryType
            .GetInterfaces()
            .FirstOrDefault(static type => type.IsGenericType && type.GetGenericTypeDefinition() == typeof(System.Collections.Generic.IDictionary<,>));
        return dictionaryInterface?.GetGenericArguments()[0] ?? typeof(object);
    }

    private static object ConvertVariantToKey(Variant key, Type keyType)
    {
        try
        {
            if (keyType == typeof(int))
            {
                return key.AsInt32();
            }

            if (keyType == typeof(long))
            {
                return key.AsInt64();
            }

            if (keyType == typeof(string))
            {
                return key.AsString();
            }

            if (keyType.IsEnum)
            {
                return Enum.Parse(keyType, key.AsString(), true);
            }

            return Convert.ChangeType(key.AsString(), keyType, CultureInfo.InvariantCulture);
        }
        catch (Exception)
        {
            return null;
        }
    }

    private static object GetPropertyValue(object target, string propertyName)
    {
        return target.GetType().GetProperty(propertyName, BindingFlags.Instance | BindingFlags.Public)?.GetValue(target);
    }

    private static bool TryGetMemberValue(object target, string memberName, out object value)
    {
        value = null;
        var bindingFlags = BindingFlags.Instance | BindingFlags.Public | BindingFlags.IgnoreCase;
        var property = target.GetType().GetProperty(memberName, bindingFlags);
        if (property != null)
        {
            value = property.GetValue(target);
            return true;
        }

        var field = target.GetType().GetField(memberName, bindingFlags);
        if (field != null)
        {
            value = field.GetValue(target);
            return true;
        }

        return false;
    }

    private static Godot.Collections.Dictionary ConvertObjectToDictionary(object value)
    {
        var result = new Godot.Collections.Dictionary();
        if (value == null)
        {
            return result;
        }

        var bindingFlags = BindingFlags.Instance | BindingFlags.Public;
        foreach (var field in value.GetType().GetFields(bindingFlags))
        {
            result[field.Name] = ConvertObjectToVariant(field.GetValue(value));
        }

        foreach (var property in value.GetType().GetProperties(bindingFlags))
        {
            if (property.GetIndexParameters().Length > 0 || !property.CanRead)
            {
                continue;
            }

            result[property.Name] = ConvertObjectToVariant(property.GetValue(value));
        }

        return result;
    }

    private static Variant ConvertObjectToVariant(object value)
    {
        if (value == null)
        {
            return default;
        }

        if (value is string stringValue)
        {
            return stringValue;
        }

        if (value is bool boolValue)
        {
            return boolValue;
        }

        if (value is int intValue)
        {
            return intValue;
        }

        if (value is long longValue)
        {
            return longValue;
        }

        if (value is float floatValue)
        {
            return floatValue;
        }

        if (value is double doubleValue)
        {
            return doubleValue;
        }

        if (value is Enum enumValue)
        {
            return enumValue.ToString();
        }

        if (value is IDictionary dictionaryValue)
        {
            var dictionary = new Godot.Collections.Dictionary();
            foreach (DictionaryEntry entry in dictionaryValue)
            {
                dictionary[ConvertObjectToVariant(entry.Key)] = ConvertObjectToVariant(entry.Value);
            }

            return dictionary;
        }

        if (value is IEnumerable enumerableValue && value is not string)
        {
            var array = new Godot.Collections.Array();
            foreach (var item in enumerableValue)
            {
                array.Add(ConvertObjectToVariant(item));
            }

            return array;
        }

        return ConvertObjectToDictionary(value);
    }
}
