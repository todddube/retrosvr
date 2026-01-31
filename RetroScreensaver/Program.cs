using System.Runtime.InteropServices;
using RetroScreensaver.Forms;

namespace RetroScreensaver;

/// <summary>
/// Main entry point for the Retro 8-Bit Screensaver.
/// Handles Windows screensaver command-line arguments:
/// /s - Run screensaver in full screen
/// /p [hwnd] - Preview in the small window on the Screen Saver settings dialog
/// /c - Show configuration dialog
/// (none) - Same as /c
/// </summary>
static partial class Program
{
    [LibraryImport("user32.dll")]
    private static partial IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

    [LibraryImport("user32.dll")]
    private static partial int SetWindowLong(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [LibraryImport("user32.dll", SetLastError = true)]
    private static partial int GetWindowLong(IntPtr hWnd, int nIndex);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    private const int GWL_STYLE = -16;
    private const int WS_CHILD = 0x40000000;

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [STAThread]
    static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.SetHighDpiMode(HighDpiMode.SystemAware);

        if (args.Length == 0)
        {
            ShowConfigDialog();
            return;
        }

        string arg = args[0].ToLower().Trim();

        if (arg.StartsWith("/c") || arg.StartsWith("-c"))
        {
            ShowConfigDialog();
        }
        else if (arg.StartsWith("/p") || arg.StartsWith("-p"))
        {
            IntPtr previewHandle = IntPtr.Zero;

            if (args.Length > 1)
            {
                previewHandle = new IntPtr(long.Parse(args[1]));
            }
            else if (arg.Length > 2)
            {
                string handleStr = arg[2..].TrimStart(':');
                previewHandle = new IntPtr(long.Parse(handleStr));
            }

            if (previewHandle != IntPtr.Zero)
            {
                ShowPreview(previewHandle);
            }
        }
        else if (arg.StartsWith("/s") || arg.StartsWith("-s"))
        {
            ShowScreensaver();
        }
        else
        {
            ShowConfigDialog();
        }
    }

    private static void ShowConfigDialog()
    {
        Application.Run(new SettingsForm());
    }

    private static void ShowPreview(IntPtr parentHandle)
    {
        if (GetClientRect(parentHandle, out RECT rect))
        {
            var form = new ScreensaverForm(true)
            {
                FormBorderStyle = FormBorderStyle.None,
                ShowInTaskbar = false,
                TopLevel = false,
                Size = new Size(rect.Right - rect.Left, rect.Bottom - rect.Top),
                Location = new Point(0, 0)
            };

            SetParent(form.Handle, parentHandle);

            int style = GetWindowLong(form.Handle, GWL_STYLE);
            _ = SetWindowLong(form.Handle, GWL_STYLE, new IntPtr(style | WS_CHILD));

            form.Show();
            Application.Run(form);
        }
    }

    private static void ShowScreensaver()
    {
        foreach (Screen screen in Screen.AllScreens)
        {
            var form = new ScreensaverForm(false)
            {
                StartPosition = FormStartPosition.Manual,
                Location = screen.Bounds.Location,
                Size = screen.Bounds.Size
            };

            form.Show();
        }

        Application.Run();
    }
}
