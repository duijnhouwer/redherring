function val=lkSettings(str,when)
   
    % 2014-10-28: Measured luminance BENQ XL2420Z screen Two-Photon room
    % Brightness 0; contrast 50; black eq 15; color temp [R G B] correction =
    % [0 100 100] blur reduction OFF; dynamic contrast 0 Resolution 1920x1080
    % 60 Hz; Reset Color no; AMA high, Instant OFF, Sharpness 1; Dynamic
    % Contrast 0; Display mode Full; Color format RGB; Smartfocus OFF;
    % connected with a VGA cable (so that we can split to Beetronixs Screen)
    % With these settings. FullWhite=42 cd/m2; FullBlack=0.12; and with gamma
    % 1, medium gray (RGB .5 .5 .5) = 21 cd/m2
    %
    % EXAMPLE
    %   lkSetting('STIMDIAM') % Get the current STIMDIAM value
    %   lkSettings('CONTRASTRANGE',datenum(1-Oct-2010)) 
    %   lkSettings('CONTRASTRANGE',datenum('1-Jan-2012'))
    %
    % Jacob Duijnhouwer
    % 2015-11-24: added the when option
    
    if ~exist('when','var') || isempty(when)
        when=now;
    end
    
    switch(upper(str))
        case 'CONTRASTRANGE'
            if when<datenum('6-Jul-2016')
                val=[0.0625 0.125 0.25 .5 1];
            else
                val=[0.125 0.25 .5 1];
            end
        case 'CONTRASTFIX'
            val=1;
        case 'SFRANGE'
            val=[0.05 0.1 0.2];
        case 'SFFIX'
            val=0.1;
        case 'TFRANGE'
            val=[0.25 0.5 1 2 4];
        case 'TFRANGE4DOTS'
            val=[0.9 1.8 3.6 5.4 7.2]; % 2016-07-06
        case 'TFFIX'
            val=1; %3.6 for dots
        case 'DOTDIAMFACTOR'
            val=[0.25 0.5 1 2 4];
        case 'DOTDIAMFIX'
            val=10/6;%1/sf/6 with sf = 0.1
        case 'SCRWIDHEIMM'
            val=[531 298]; % BENQ XL2420Z nagemeten d.d. XXXXXXX
        case 'BACKRGBA'
            val=[.5 .5 .5 1];
        case 'VIEWDISTMM'
            val=290;
        case 'GAMMA'
            val=1;
        case 'STIMDIAM'
            val=47;
        case 'STIMSEC'
            val=4;
        case 'ISISEC'
            val=4;
        case '2PHOTONEXTRASECS'
            val=120;
        case 'VERBOSITY'
            val=2; % tussen 0 en 5
        case 'WINPIX'
            val=[0 0 1920 1080];
        case 'WINPIXDEBUG'
            val=[10 10 640 360];
        case 'SKIPSYNCTEST'
            val=1;
        case 'TESTDIRS'
            val=0:45:315;
        case 'MCCPIN'
            val=13;
        otherwise
            error(['Unknown setting: ' str]);
    end