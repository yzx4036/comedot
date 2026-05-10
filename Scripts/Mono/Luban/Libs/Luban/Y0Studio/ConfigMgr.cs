using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using Luban;

namespace Y0Studio.Config
{
	/// <summary>
	/// Godot 侧的 Luban 配置表提供器。
	/// 负责发现所有标记了 <see cref="ConfigAttribute"/> 的配置表、加载二进制数据、注册单例并解析引用。
	/// </summary>
	public class ConfigMgr : IDisposable
	{
		public const string DefaultConfigNamespacePrefix = "Y0Studio.Config";
		public const string DefaultConfigDirectory = "res://assets/configs/tables";

		private readonly ConcurrentDictionary<Type, IConfigSingleton> _tables = new();
		private readonly Dictionary<string, IConfigSingleton> _tablesByConfigName = new(StringComparer.OrdinalIgnoreCase);

		public string ConfigDirectory { get; }
		public string ConfigNamespacePrefix { get; }
		public IReadOnlyCollection<string> ConfigNames => _tablesByConfigName.Keys.ToArray();

		public ConfigMgr() : this(DefaultConfigDirectory, DefaultConfigNamespacePrefix)
		{
		}

		public ConfigMgr(string configDirectory) : this(configDirectory, DefaultConfigNamespacePrefix)
		{
		}

		public ConfigMgr(string configDirectory, string configNamespacePrefix) : this(configDirectory, configNamespacePrefix, name => LoadByteBuf(configDirectory, name))
		{
		}

		public ConfigMgr(Func<string, ByteBuf> loader) : this(DefaultConfigDirectory, DefaultConfigNamespacePrefix, loader)
		{
		}

		public ConfigMgr(string configDirectory, Func<string, ByteBuf> loader) : this(configDirectory, DefaultConfigNamespacePrefix, loader)
		{
		}

		private ConfigMgr(string configDirectory, string configNamespacePrefix, Func<string, ByteBuf> loader)
		{
			if (loader == null)
			{
				throw new ArgumentNullException(nameof(loader));
			}

			if (string.IsNullOrWhiteSpace(configDirectory))
			{
				throw new ArgumentException("配置目录不能为空", nameof(configDirectory));
			}

			ConfigDirectory = NormalizeConfigDirectory(configDirectory);
			ConfigNamespacePrefix = string.IsNullOrWhiteSpace(configNamespacePrefix) ? DefaultConfigNamespacePrefix : configNamespacePrefix.Trim();

			foreach (var tableType in DiscoverConfigTypes(ConfigNamespacePrefix))
			{
				var configName = BuildConfigName(tableType, ConfigNamespacePrefix);
				var byteBuf = loader(configName) ?? throw new FileNotFoundException($"配置表加载失败: {configName}");
				var table = CreateTable(tableType, byteBuf);
				RegisterTable(configName, table);
			}

			ResolveAll();
		}

		private static ByteBuf LoadByteBuf(string configDirectory, string name)
		{
			var path = $"{NormalizeConfigDirectory(configDirectory)}/{name}.bytes";
			if (!Godot.FileAccess.FileExists(path))
			{
				throw new FileNotFoundException($"配置文件不存在: {path}", path);
			}

			var bytes = Godot.FileAccess.GetFileAsBytes(path);
			return new ByteBuf(bytes);
		}

		private static string NormalizeConfigDirectory(string configDirectory)
		{
			return configDirectory.Trim().TrimEnd('/', '\\');
		}

		public bool TryGet<T>(out T table) where T : class, IConfigSingleton
		{
			if (_tables.TryGetValue(typeof(T), out var value))
			{
				table = (T)value;
				return true;
			}

			table = null;
			return false;
		}

		public bool TryGetByConfigName(string configName, out IConfigSingleton table)
		{
			return _tablesByConfigName.TryGetValue(configName, out table);
		}

		public void Dispose()
		{
			foreach (var table in _tables.Values.Reverse())
			{
				table.Destroy();
			}

			_tables.Clear();
			_tablesByConfigName.Clear();
		}

		private static IReadOnlyList<Type> DiscoverConfigTypes(string configNamespacePrefix)
		{
			var assembly = typeof(ConfigMgr).Assembly;
			var allTypes = GetLoadableTypes(assembly);

			return allTypes
				.Where(type => type is { IsClass: true, IsAbstract: false })
				.Where(type => typeof(IConfigSingleton).IsAssignableFrom(type))
				.Where(type => type.GetCustomAttribute<ConfigAttribute>() != null)
				.Where(type => string.IsNullOrWhiteSpace(configNamespacePrefix)
					|| (type.Namespace?.StartsWith(configNamespacePrefix, StringComparison.Ordinal) ?? false))
				.OrderBy(type => type.FullName, StringComparer.Ordinal)
				.ToArray();
		}

		private static IEnumerable<Type> GetLoadableTypes(Assembly assembly)
		{
			try
			{
				return assembly.GetTypes();
			}
			catch (ReflectionTypeLoadException ex)
			{
				return ex.Types.Where(type => type != null)!;
			}
		}

		private static string BuildConfigName(Type tableType, string configNamespacePrefix)
		{
			var namespaceSuffix = tableType.Namespace;
			if (!string.IsNullOrEmpty(namespaceSuffix) && namespaceSuffix.StartsWith(configNamespacePrefix, StringComparison.Ordinal))
			{
				namespaceSuffix = namespaceSuffix.Substring(configNamespacePrefix.Length).Trim('.');
			}

			var parts = new List<string>();
			if (!string.IsNullOrWhiteSpace(namespaceSuffix))
			{
				parts.AddRange(namespaceSuffix
					.Split('.', StringSplitOptions.RemoveEmptyEntries)
					.Select(static part => part.ToLowerInvariant()));
			}

			parts.Add(tableType.Name.ToLowerInvariant());
			return string.Join("_", parts);
		}

		private static IConfigSingleton CreateTable(Type tableType, ByteBuf byteBuf)
		{
			var ctor = tableType.GetConstructor(new[] { typeof(ByteBuf) });
			if (ctor == null)
			{
				throw new MissingMethodException(tableType.FullName, ".ctor(ByteBuf)");
			}

			return (IConfigSingleton)ctor.Invoke(new object[] { byteBuf });
		}

		private void RegisterTable(string configName, IConfigSingleton table)
		{
			table.Register();

			if (!_tables.TryAdd(table.GetType(), table))
			{
				throw new InvalidOperationException($"重复注册配置表类型: {table.GetType().FullName}");
			}

			if (!_tablesByConfigName.TryAdd(configName, table))
			{
				throw new InvalidOperationException($"重复注册配置表名: {configName}");
			}
		}

		private void ResolveAll()
		{
			foreach (var table in _tables.Values)
			{
				table.Resolve(_tables);
			}
		}
	}
}
