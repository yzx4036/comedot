using Godot;
using Comedot.Config;
using Y0Studio.Config;
using Y0Studio.Config.Examples;

namespace Game;

public partial class GameMain : Node
{
    [Export(PropertyHint.Dir)]
    public string ConfigDirectory { get; set; } = ConfigMgr.DefaultConfigDirectory;

    [Export]
    public string ConfigNamespacePrefix { get; set; } = ConfigMgr.DefaultConfigNamespacePrefix;

    private LubanConfigService _configService;

    public ConfigMgr ConfigMgr { get; private set; }

    public override void _Ready()
    {
        _configService = new LubanConfigService
        {
            ConfigDirectory = ConfigDirectory,
            ConfigNamespacePrefix = ConfigNamespacePrefix,
            LoadOnReady = false,
        };
        AddChild(_configService);

        if (!_configService.LoadConfigs())
        {
            return;
        }

        ConfigMgr = _configService.ConfigMgr;
        DebugPrintConfig();
        RefreshConfigViews();
    }

    public override void _ExitTree()
    {
        _configService?.UnloadConfigs();
        ConfigMgr = null;
    }


    private void RefreshConfigViews()
    {
        foreach (Node node in GetTree().GetNodesInGroup("lubanConfigViews"))
        {
            if (node is ConfigsDetailView configView)
            {
                configView.Refresh();
            }
        }
    }


    // 调试打印配置表内容
    private void DebugPrintConfig()
    {
        // Tables.TbExampleBasic 对应配置表 ExampleBasic
        var item = TbExampleBasic.Instance.GetOrDefault(1001);
        if (item == null)
        {
            GD.PushError("Luban config test failed: examples_tbexamplebasic.bytes does not contain id 1001.");
            return;
        }

        // 通过id获取记录
        GD.Print($"Luban config loaded: {item.Id} {item.Name} {item.Type}");
        // 获取所有记录
        var dataList = TbExampleBasic.Instance.DataList;
        for (int i = 0; i < dataList.Count; i++)
        {
            GD.Print($"{dataList[i].Id} {dataList[i].Name} {dataList[i].Type}");
        }
    }
}
