using System.Text.Json;
using Godot;
using Y0Studio.Config;
using Y0Studio.Config.Examples;

namespace Game;

public partial class GameMain : Node
{
    public ConfigMgr ConfigMgr { get; private set; }

    public override void _Ready()
    {
        // 使用 -c cs-dotnet-json^ -d json 导出时
        // Tables = new Tables(LoadJson);
        // 使用-c cs-bin^ -d bin 导出时
        ConfigMgr = new ConfigMgr();
        DebugPrintConfig();
    }

    public override void _ExitTree()
    {
        ConfigMgr?.Dispose();
        ConfigMgr = null;
    }

    private JsonElement LoadJson(string name)
    {
        var file = FileAccess.Open($"{ConfigMgr.DefaultConfigDirectory}/{name}.json", FileAccess.ModeFlags.Read);
        var text = file.GetAsText();
        file.Close();
        var jsonDocument = JsonDocument.Parse(text);
        return jsonDocument.RootElement;
    }


    // 调试打印配置表内容
    private void DebugPrintConfig()
    {
        // Tables.TbExampleBasic 对应配置表 ExampleBasic
        var item = TbExampleBasic.Instance.GetOrDefault(1001);
        // 通过id获取记录
        GD.Print(string.Format("{0} {1} {2}", item.Id, item.Name, item.Type));
        // 获取所有记录
        var dataList = TbExampleBasic.Instance.DataList;
        for (int i = 0; i < dataList.Count; i++)
        {
            GD.Print(string.Format("{0} {1} {2}", dataList[i].Id, dataList[i].Name, dataList[i].Type));
        }
    }
}
