using System;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace RozaCompanion.ViewModels;

public partial class ChatAttachmentItemVm : ObservableObject
{
    private readonly Action<ChatAttachmentItemVm> _onRemove;

    public ChatAttachmentItemVm(string filename, string content, Action<ChatAttachmentItemVm> onRemove)
    {
        Filename = filename;
        Content = content;
        _onRemove = onRemove;
    }

    public string Filename { get; }

    public string Content { get; }

    public int CharCount => Content.Length;

    public string Summary => $"{Filename} ({CharCount:N0} симв.)";

    [RelayCommand]
    private void Remove() => _onRemove(this);
}
