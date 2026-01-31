using RetroScreensaver.Core;

namespace RetroScreensaver.Forms;

/// <summary>
/// Settings dialog for screensaver configuration.
/// </summary>
public class SettingsForm : Form
{
    private ComboBox _effectCombo = null!;
    private TrackBar _durationSlider = null!;
    private TrackBar _pixelScaleSlider = null!;
    private TrackBar _frameRateSlider = null!;
    private CheckBox _smoothTransitionsCheck = null!;
    private Label _durationLabel = null!;
    private Label _scaleLabel = null!;
    private Label _fpsLabel = null!;
    private Button _previewButton = null!;
    private Button _okButton = null!;
    private Button _cancelButton = null!;

    public SettingsForm()
    {
        InitializeComponent();
        LoadSettings();
    }

    private void InitializeComponent()
    {
        Text = "Retro 8-Bit Screensaver Settings";
        Size = new Size(420, 410);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(30, 30, 35);
        ForeColor = Color.FromArgb(0, 255, 128);
        Font = new Font("Consolas", 10);

        // Title
        var titleLabel = new Label
        {
            Text = "RETRO 8-BIT SCREENSAVER",
            Font = new Font("Consolas", 14, FontStyle.Bold),
            ForeColor = Color.FromArgb(0, 255, 128),
            AutoSize = true,
            Location = new Point(80, 15)
        };

        // Effect selection
        var effectLabel = new Label
        {
            Text = "Effect:",
            Location = new Point(20, 55),
            AutoSize = true
        };

        _effectCombo = new ComboBox
        {
            Location = new Point(120, 52),
            Size = new Size(260, 25),
            DropDownStyle = ComboBoxStyle.DropDownList,
            BackColor = Color.FromArgb(45, 45, 50),
            ForeColor = Color.FromArgb(0, 255, 128)
        };
        _effectCombo.Items.AddRange(new object[]
        {
            "All Effects (Cycle)",
            "Starfield",
            "Plasma",
            "Fire",
            "Matrix Rain",
            "Sine Scroller",
            "Dissolver"
        });

        // Duration slider
        var durationTitleLabel = new Label
        {
            Text = "Effect Duration:",
            Location = new Point(20, 95),
            AutoSize = true
        };

        _durationSlider = new TrackBar
        {
            Location = new Point(20, 115),
            Size = new Size(320, 45),
            Minimum = 5,
            Maximum = 120,
            TickFrequency = 10,
            BackColor = Color.FromArgb(30, 30, 35)
        };
        _durationSlider.ValueChanged += (s, e) => UpdateLabels();

        _durationLabel = new Label
        {
            Location = new Point(345, 120),
            Size = new Size(50, 20),
            TextAlign = ContentAlignment.MiddleLeft
        };

        // Pixel scale slider
        var scaleTitleLabel = new Label
        {
            Text = "Pixel Scale:",
            Location = new Point(20, 160),
            AutoSize = true
        };

        _pixelScaleSlider = new TrackBar
        {
            Location = new Point(20, 180),
            Size = new Size(320, 45),
            Minimum = 1,
            Maximum = 8,
            TickFrequency = 1,
            BackColor = Color.FromArgb(30, 30, 35)
        };
        _pixelScaleSlider.ValueChanged += (s, e) => UpdateLabels();

        _scaleLabel = new Label
        {
            Location = new Point(345, 185),
            Size = new Size(50, 20),
            TextAlign = ContentAlignment.MiddleLeft
        };

        // Frame rate slider
        var fpsTitleLabel = new Label
        {
            Text = "Frame Rate:",
            Location = new Point(20, 225),
            AutoSize = true
        };

        _frameRateSlider = new TrackBar
        {
            Location = new Point(20, 245),
            Size = new Size(320, 45),
            Minimum = 15,
            Maximum = 60,
            TickFrequency = 5,
            BackColor = Color.FromArgb(30, 30, 35)
        };
        _frameRateSlider.ValueChanged += (s, e) => UpdateLabels();

        _fpsLabel = new Label
        {
            Location = new Point(345, 250),
            Size = new Size(60, 20),
            TextAlign = ContentAlignment.MiddleLeft
        };

        // Smooth transitions checkbox
        _smoothTransitionsCheck = new CheckBox
        {
            Text = "Smooth Transitions",
            Location = new Point(20, 290),
            AutoSize = true,
            ForeColor = Color.FromArgb(0, 255, 128)
        };

        // Buttons
        _previewButton = new Button
        {
            Text = "Preview",
            Location = new Point(20, 320),
            Size = new Size(100, 30),
            BackColor = Color.FromArgb(45, 45, 50),
            ForeColor = Color.FromArgb(0, 255, 128),
            FlatStyle = FlatStyle.Flat
        };
        _previewButton.Click += OnPreviewClick;

        _okButton = new Button
        {
            Text = "OK",
            Location = new Point(200, 320),
            Size = new Size(80, 30),
            BackColor = Color.FromArgb(45, 45, 50),
            ForeColor = Color.FromArgb(0, 255, 128),
            FlatStyle = FlatStyle.Flat,
            DialogResult = DialogResult.OK
        };
        _okButton.Click += OnOkClick;

        _cancelButton = new Button
        {
            Text = "Cancel",
            Location = new Point(300, 320),
            Size = new Size(80, 30),
            BackColor = Color.FromArgb(45, 45, 50),
            ForeColor = Color.FromArgb(0, 255, 128),
            FlatStyle = FlatStyle.Flat,
            DialogResult = DialogResult.Cancel
        };

        Controls.AddRange(new Control[]
        {
            titleLabel, effectLabel, _effectCombo,
            durationTitleLabel, _durationSlider, _durationLabel,
            scaleTitleLabel, _pixelScaleSlider, _scaleLabel,
            fpsTitleLabel, _frameRateSlider, _fpsLabel,
            _smoothTransitionsCheck,
            _previewButton, _okButton, _cancelButton
        });

        AcceptButton = _okButton;
        CancelButton = _cancelButton;
    }

    private void LoadSettings()
    {
        Settings.Load();

        _effectCombo.SelectedIndex = Settings.CurrentEffect == EffectType.All ? 0 : (int)Settings.CurrentEffect + 1;
        _durationSlider.Value = Math.Clamp(Settings.EffectDuration, 5, 120);
        _pixelScaleSlider.Value = Math.Clamp(Settings.PixelScale, 1, 8);
        _frameRateSlider.Value = Math.Clamp(Settings.FrameRate, 15, 60);
        _smoothTransitionsCheck.Checked = Settings.SmoothTransitions;

        UpdateLabels();
    }

    private void UpdateLabels()
    {
        _durationLabel.Text = $"{_durationSlider.Value}s";
        _scaleLabel.Text = $"{_pixelScaleSlider.Value}x";
        _fpsLabel.Text = $"{_frameRateSlider.Value} FPS";
    }

    private void SaveSettings()
    {
        Settings.CurrentEffect = _effectCombo.SelectedIndex == 0 ? EffectType.All : (EffectType)(_effectCombo.SelectedIndex - 1);
        Settings.EffectDuration = _durationSlider.Value;
        Settings.PixelScale = _pixelScaleSlider.Value;
        Settings.FrameRate = _frameRateSlider.Value;
        Settings.SmoothTransitions = _smoothTransitionsCheck.Checked;
        Settings.Save();
    }

    private void OnPreviewClick(object? sender, EventArgs e)
    {
        SaveSettings();

        using var previewForm = new ScreensaverForm(true)
        {
            WindowState = FormWindowState.Normal,
            Size = new Size(800, 600),
            StartPosition = FormStartPosition.CenterScreen,
            TopMost = false
        };
        previewForm.ShowDialog(this);
    }

    private void OnOkClick(object? sender, EventArgs e)
    {
        SaveSettings();
        Close();
    }
}
