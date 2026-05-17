using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace RozaCompanion.Services;

/// <summary>Снимок локальной папки для контекста модели (дерево + фрагменты текстовых файлов).</summary>
public static class RepositorySnapshotBuilder
{
    private static readonly HashSet<string> SkipDirNames = new(StringComparer.OrdinalIgnoreCase)
    {
        ".git", "node_modules", "__pycache__", ".venv", "venv", "bin", "obj", ".vs", "dist", "build",
        ".idea", ".cursor", "packages", "target", ".next", ".nuget",
    };

    private static readonly HashSet<string> TextExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".cs", ".py", ".js", ".ts", ".tsx", ".jsx", ".json", ".yaml", ".yml", ".md", ".txt", ".html",
        ".css", ".xml", ".rs", ".go", ".java", ".kt", ".sql", ".sh", ".ps1", ".axaml", ".xaml", ".toml",
        ".props", ".csproj", ".sln", ".gitignore", ".env", ".ini", ".cfg",
    };

    public const int MaxTotalChars = 1_200_000;

    public static string Build(string rootPath, int maxContentFiles = 200, int maxDirNodes = 800)
    {
        var root = Path.GetFullPath(rootPath);
        if (!Directory.Exists(root))
            throw new DirectoryNotFoundException(root);

        var sb = new StringBuilder();
        sb.AppendLine("# Снимок репозитория (локально)");
        sb.AppendLine("Корень: `" + root + "`");
        sb.AppendLine();

        var treeLines = new List<string>();
        var dirs = new Queue<(string Path, int Depth)>();
        dirs.Enqueue((root, 0));
        var visitedDirs = 0;
        while (dirs.Count > 0 && visitedDirs < maxDirNodes)
        {
            var (dir, depth) = dirs.Dequeue();
            visitedDirs++;
            var rel = dir.Length > root.Length ? dir[(root.Length + 1)..] : ".";
            treeLines.Add(new string(' ', depth * 2) + "[dir] " + rel);

            IEnumerable<string> sub;
            try
            {
                sub = Directory.EnumerateDirectories(dir);
            }
            catch
            {
                continue;
            }

            foreach (var sd in sub.OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
            {
                var name = Path.GetFileName(sd);
                if (string.IsNullOrEmpty(name) || SkipDirNames.Contains(name))
                    continue;
                if (depth < 12)
                    dirs.Enqueue((sd, depth + 1));
            }
        }

        sb.AppendLine("## Дерево каталогов (фрагмент)");
        sb.AppendLine("```");
        foreach (var line in treeLines.Take(2000))
            sb.AppendLine(line);
        if (treeLines.Count > 2000)
            sb.AppendLine("…");
        sb.AppendLine("```");
        sb.AppendLine();

        var filesForBody = CollectTextFiles(root, maxContentFiles);

        sb.AppendLine("## Файлы (содержимое, усечено)");
        var total = sb.Length;
        foreach (var fp in filesForBody)
        {
            string rel;
            try
            {
                rel = Path.GetRelativePath(root, fp);
            }
            catch
            {
                rel = fp;
            }

            string body;
            try
            {
                body = File.ReadAllText(fp);
            }
            catch
            {
                continue;
            }

            if (body.Length > 48_000)
                body = body[..48_000] + "\n…[обрезано]";
            var block = "### `" + rel + "`\n```\n" + body + "\n```\n\n";
            if (total + block.Length > MaxTotalChars)
            {
                sb.AppendLine("…дальнейшие файлы опущены (лимит размера снимка).");
                break;
            }

            sb.Append(block);
            total += block.Length;
        }

        return sb.ToString();
    }

    private static List<string> CollectTextFiles(string root, int maxFiles)
    {
        var result = new List<string>();
        var q = new Queue<string>();
        q.Enqueue(root);
        var dirBudget = 4000;
        while (q.Count > 0 && dirBudget-- > 0 && result.Count < maxFiles)
        {
            var dir = q.Dequeue();
            string[] files;
            try
            {
                files = Directory.GetFiles(dir);
            }
            catch
            {
                continue;
            }

            foreach (var f in files.OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
            {
                if (result.Count >= maxFiles)
                    return result;
                var ext = Path.GetExtension(f);
                if (string.IsNullOrEmpty(ext))
                {
                    var bn = Path.GetFileName(f);
                    if (bn is "Dockerfile" or "Makefile" or "LICENSE")
                        result.Add(f);
                    continue;
                }

                if (TextExtensions.Contains(ext))
                    result.Add(f);
            }

            string[] subdirs;
            try
            {
                subdirs = Directory.GetDirectories(dir);
            }
            catch
            {
                continue;
            }

            foreach (var sd in subdirs)
            {
                var name = Path.GetFileName(sd);
                if (!string.IsNullOrEmpty(name) && !SkipDirNames.Contains(name))
                    q.Enqueue(sd);
            }
        }

        return result;
    }
}
