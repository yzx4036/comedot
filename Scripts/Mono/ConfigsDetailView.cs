using System.Text;
using Godot;
using Y0Studio.Config.Examples;

namespace Game;

public partial class ConfigsDetailView : Node
{
    [Export]
    private Label _info1;

    [Export]
    private Label _info2;

    public void Refresh()
    {
        ResolveInfoLabels();
        if (_info1 == null || _info2 == null)
        {
            GD.PushError("ConfigsDetailView requires both info labels.");
            return;
        }

        var sb = new StringBuilder("基础示例表中所有记录：\n");
        foreach (var it in TbExampleBasic.Instance.DataList)
        {
            sb.AppendLine($"{it.Id} {it.Name} {it.Type}");
        }

        sb.AppendLine("\n根据id获取基础示例表中单条记录：");
        var item = TbExampleBasic.Instance.GetOrDefault(1001);
        if (item != null)
        {
            sb.AppendLine($"{item.Id} {item.Name} {item.Type}");
        }

        _info1.Text = sb.ToString();

        sb = new StringBuilder("列表表中所有记录：\n");
        foreach (var it in TbExampleList.Instance.DataList)
        {
            sb.AppendLine($"{it.Name} {it.Race} {it.Occupation} {it.Age}岁 {it.Origin}");
        }

        sb.AppendLine("\n根据下标获取列表表中指定记录：");
        if (TbExampleList.Instance.DataList.Count > 3)
        {
            var item1 = TbExampleList.Instance.DataList[3];
            sb.AppendLine($"{item1.Name} {item1.Race} {item1.Occupation} {item1.Age}岁 {item1.Origin}");
        }

        _info2.Text = sb.ToString();
    }


    private void ResolveInfoLabels()
    {
        _info1 ??= GetNodeOrNull<Label>("Info1");
        _info2 ??= GetNodeOrNull<Label>("Info2");
    }
}
