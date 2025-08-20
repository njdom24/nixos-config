{ inputs, config, ... }: {
  xdg.dataFile."color-schemes/base16.colors".text = ''
    [General]
    ColorScheme=Base16
    Name=Base16
    
    [Colors:Window]
    BackgroundNormal=#${config.colorScheme.palette.base00}
    ForegroundNormal=#${config.colorScheme.palette.base05}
    
    [Colors:View]
    BackgroundNormal=#141618
    ForegroundNormal=#${config.colorScheme.palette.base05}
    
    [Colors:Button]
    BackgroundNormal=#${config.colorScheme.palette.base01}
    ForegroundNormal=#${config.colorScheme.palette.base05}
    
    [Colors:Selection]
    BackgroundNormal=#${config.colorScheme.palette.base02}
    ForegroundNormal=#${config.colorScheme.palette.base05}
    
    [Colors:Tooltip]
    BackgroundNormal=#2E2E2E
    ForegroundNormal=#${config.colorScheme.palette.base06}
    
    [Colors:Link]
    ForegroundNormal=#${config.colorScheme.palette.base0D}
    ForegroundVisited=#${config.colorScheme.palette.base0E}

    [Colors:Inactive]
    BackgroundNormal=#2E2E2E
    ForegroundNormal=#${config.colorScheme.palette.base05}
    
    [Colors:Complementary]
    NegativeText=#${config.colorScheme.palette.base08}
    NeutralText=#${config.colorScheme.palette.base09}
    PositiveText=#${config.colorScheme.palette.base0B}
  '';
}
