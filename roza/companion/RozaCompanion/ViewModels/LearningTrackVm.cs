namespace RozaCompanion.ViewModels;

/// <summary>Карточка ориентира по сценарию обучения (без «живых» процентов — только текст).</summary>
public sealed class LearningTrackVm
{
    public LearningTrackVm(string title, string subtitle, string body)
    {
        Title = title;
        Subtitle = subtitle;
        Body = body;
    }

    public string Title { get; }
    public string Subtitle { get; }
    public string Body { get; }
}
