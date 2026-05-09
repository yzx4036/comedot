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

    public override void _Ready() 
    {

        var sb = new StringBuilder("基础示例表中所有记录：\n");
        foreach (var it in TbExampleBasic.Instance.DataList) 
        {
            sb.AppendLine(string.Format("{0} {1} {2}", it.Id, it.Name, it.Type));
        }

        sb.AppendLine("\n根据id获取基础示例表中单条记录：");
        var item = TbExampleBasic.Instance.GetOrDefault(1001);
	    sb.AppendLine(string.Format("{0} {1} {2}", item.Id, item.Name, item.Type));

        _info1.Text = sb.ToString();

        sb = new StringBuilder("列表表中所有记录：\n");
        foreach (var it in TbExampleList.Instance.DataList) 
        {
            sb.AppendLine(string.Format("{0} {1} {2} {3}岁 {4}", it.Name, it.Race, it.Occupation, it.Age, it.Origin));
        }

        sb.AppendLine("\n根据下标获取列表表中指定记录：");
        var item1 = TbExampleList.Instance.DataList[3];
        sb.AppendLine(string.Format("{0} {1} {2} {3}岁 {4}", item1.Name, item1.Race, item1.Occupation, item1.Age, item1.Origin));

        _info2.Text = sb.ToString();
    }

}
