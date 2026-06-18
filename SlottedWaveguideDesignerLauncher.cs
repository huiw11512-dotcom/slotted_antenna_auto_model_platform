using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class SlottedWaveguideDesignerLauncher
{
    [STAThread]
    private static void Main()
    {
        string appDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
        string scriptPath = Path.Combine(appDir, "run_full_antenna_model.m");
        if (!File.Exists(scriptPath))
        {
            MessageBox.Show("Cannot find run_full_antenna_model.m next to this launcher.",
                "Slotted Waveguide Designer", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        string matlabExe = FindMatlab();
        if (string.IsNullOrEmpty(matlabExe))
        {
            MessageBox.Show("Cannot find matlab.exe. Set SLOTTED_ARRAY_MATLAB, add MATLAB to PATH, or install MATLAB under a standard MATLAB folder.",
                "Slotted Waveguide Designer", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        string matlabCmd = "try, cd('" + EscapeMatlabString(appDir) + "'); " +
            "run('run_full_antenna_model.m'); " +
            "catch ME, disp(getReport(ME,'extended')); end";

        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = matlabExe;
        psi.Arguments = "-r \"" + matlabCmd.Replace("\"", "\\\"") + "\"";
        psi.WorkingDirectory = appDir;
        psi.UseShellExecute = false;
        Process.Start(psi);
    }

    private static string FindMatlab()
    {
        string envPath = Environment.GetEnvironmentVariable("SLOTTED_ARRAY_MATLAB") ?? "";
        if (File.Exists(envPath))
        {
            return envPath;
        }

        string path = Environment.GetEnvironmentVariable("PATH") ?? "";
        foreach (string dir in path.Split(Path.PathSeparator))
        {
            try
            {
                string candidate = Path.Combine(dir.Trim(), "matlab.exe");
                if (File.Exists(candidate))
                {
                    return candidate;
                }
            }
            catch
            {
                // Ignore malformed PATH entries.
            }
        }

        string[] fixedCandidates = new string[]
        {
            @"D:\software\Matlab\bin\matlab.exe",
            @"D:\software\MATLAB\bin\matlab.exe",
            @"D:\Program Files\MATLAB\bin\matlab.exe"
        };
        foreach (string candidate in fixedCandidates)
        {
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        string[] roots = new string[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "MATLAB"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "MATLAB"),
            @"D:\software\MATLAB",
            @"D:\Program Files\MATLAB"
        };
        foreach (string root in roots)
        {
            string candidate = FindMatlabUnderRoot(root);
            if (!string.IsNullOrEmpty(candidate))
            {
                return candidate;
            }
        }
        return "";
    }

    private static string FindMatlabUnderRoot(string root)
    {
        try
        {
            if (string.IsNullOrEmpty(root) || !Directory.Exists(root))
            {
                return "";
            }
            string[] releaseDirs = Directory.GetDirectories(root, "R*");
            Array.Sort(releaseDirs, StringComparer.OrdinalIgnoreCase);
            Array.Reverse(releaseDirs);
            foreach (string releaseDir in releaseDirs)
            {
                string candidate = Path.Combine(releaseDir, "bin", "matlab.exe");
                if (File.Exists(candidate))
                {
                    return candidate;
                }
            }
        }
        catch
        {
            // Ignore inaccessible install roots.
        }
        return "";
    }

    private static string EscapeMatlabString(string value)
    {
        return value.Replace("'", "''");
    }
}
