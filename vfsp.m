classdef vfsp < handle
%
%  vfsp
%
%  Application object of VFS (Video FluoroScopy) analyzer.


  %
  %  Properties
  %
  properties

    %
    %  Figure (Windows) handles
    %
    mainWindow  % main window object
    documents   % figure objects for document windows

    %  Dimension of mainWindow
    mainWindowWidth

    %
    %  Main window: ui controls (buttons)
    %
    buttonTitles
    buttonCallbacks
  
    %
    %  Marker keys
    %
    markerKeyCoinAnterior;
    markerKeyCoinPosterior;
    markerKeyMandibleAnterior;
    markerKeyMandiblePosterior;
    markerKeyHyoidAnterior;
    markerKeyHyoidPosterior;
    markerKeyEpiglottisTip;
    markerKeyEpiglottisBase;
    markerKeyVocalFoldAnterior;
    markerKeyVocalFoldPosterior;
    markerKeyFoodBolusHead;
    markerKeyArytenoid;
    markerKeyMaxillaAnterior;
    markerKeyMaxillaPosterior;
    markerKeyUESAnterior;
    markerKeyUESPosterior;
    markerKeyC2;
    markerKeyC4;

    
    markerDefaults           % colors, names of markers, and relationship.
    %
    %  Preferences (struct)
    %
    pref_coinMarkerSelectionCount % The number of frames to select the markers of coin.
    pref_diameterCoin             % Diameter of the coin
    pref_markersEnabled           % Flag to mark markers
                                  % enabled/disabled status
    pref_eventStrings             % Strings to describe events 
    

  end
  
  

  % ----------------------------------------------------------------------------
  %
  %                          P U B L I C    M E T H O D S
  %
  % ----------------------------------------------------------------------------
  methods
    % --------------------------------------------------------------------------
    %
    %  Method: version
    %
    %  This function returns the version of self object.
    %
    % --------------------------------------------------------------------------
    function ver = version (self)
      ver = 1.1;
    end




    % --------------------------------------------------------------------------
    %
    %  Method: vfsp
    %
    %  This function constructs and initializes a vfsp 
    %  object.
    %
    % --------------------------------------------------------------------------
    function self = vfsp 
      % Set marker keys.
      self.markerKeyCoinAnterior       = 'coin_a';
      self.markerKeyCoinPosterior      = 'coin_p';
      self.markerKeyMandibleAnterior   = 'mndbl_a';
      self.markerKeyMandiblePosterior  = 'mndbl_p';
      self.markerKeyHyoidAnterior      = 'hyd_a';
      self.markerKeyHyoidPosterior     = 'hyd_p';
      self.markerKeyEpiglottisTip      = 'epglts_t';
      self.markerKeyEpiglottisBase     = 'epglts_b';
      self.markerKeyVocalFoldAnterior  = 'vclfld_a';
      self.markerKeyVocalFoldPosterior = 'vclfld_p';
      self.markerKeyFoodBolusHead      = 'fdbls_hd';
      self.markerKeyArytenoid          = 'artnd';
      self.markerKeyMaxillaAnterior    = 'mxla_a';
      self.markerKeyMaxillaPosterior   = 'mxla_p';
      self.markerKeyUESAnterior        = 'ues_a';
      self.markerKeyUESPosterior       = 'ues_p';
      self.markerKeyC2                 = 'c2';
      self.markerKeyC4                 = 'c4';

      % Set default colors for markers
      self.markerDefaults = { ...
        1, 'Coin Anterior',        '22', '8b', '22',  2, ... % forest green
          self.markerKeyCoinAnterior; ... 

        1, 'Coin Posterior',       '22', '8b', '22',  1, ...
          self.markerKeyCoinPosterior; ...

        1, 'Mandible Anterior',    'ff', '00', '00',  4, ... % red
          self.markerKeyMandibleAnterior; ...

        0, 'Mandible Posterior',   'ff', '00', '00',  3, ...
          self.markerKeyMandiblePosterior; ...

        1, 'Hyoid Anterior',       '00', '00', 'ff',  6, ... % blue
          self.markerKeyHyoidAnterior; ...

        0, 'Hyoid Posterior',      '00', '00', 'ff',  5, ...
          self.markerKeyHyoidPosterior; ...

        1, 'Epiglottis Tip',       'd2', '69', '1e',  8, ... % chocolate
          self.markerKeyEpiglottisTip; ...

        1, 'Epiglottis Base',      'd2', '69', '1e',  7, ... 
          self.markerKeyEpiglottisBase; ...

        1, 'Larynx Anterior',  'ff', '45', '00', 10, ... % orange red
          self.markerKeyVocalFoldAnterior; ...

        0, 'Larynx Posterior', 'ff', '45', '00',  9, ... 
          self.markerKeyVocalFoldPosterior; ...

        1, 'Head of Bolus',      'b8', '86', '0b',  0, ... % dark goldenrod
          self.markerKeyFoodBolusHead; ...

        1, 'Arytenoid',            '00', 'bf', 'ff',  0, ... % deep skyblue
          self.markerKeyArytenoid; ...

        0, 'Maxilla Anterior',     'bd', 'b7', '6b', 14, ... % dark khaki
          self.markerKeyMaxillaAnterior; ...

        0, 'Maxilla Posterior',    'bd', 'b7', '6b', 13, ... 
          self.markerKeyMaxillaPosterior; ...

        0, 'UES Anterior',         'ff', '00', 'ff', 16, ... % magenta
          self.markerKeyUESAnterior; ...

        0, 'UES Posterior',        'ff', '00', 'ff', 15, ...
          self.markerKeyUESPosterior; ...

        1, 'C2 (Head of Y-axis)',  'b0', '30', '60', 18, ... % maroon
          self.markerKeyC2; ...

        1, 'C4 (Tail of Y-axis)',  'b0', '30', '60', 17, ... 
          self.markerKeyC4; ...
        };

      %  Set title and callbacks of buttons
      % ------------------------------------------------------------------------
      self.buttonTitles = { ...
        'Open a Video...', ...
        'Save Workspace...', ...
        'Preferences...', ...
        'About...', ...
        'Quit', ...
        };

      self.buttonCallbacks = { ...
        @(src, event)openDocument(self, src, event), ...
        @(src, event)saveWorkspace(self, src, event), ...
        @(src, event)showPreferencesDialog(self, src, event), ...
        @(src, event)showAboutDialog(self, src, event), ...
        @(src, event)quitApplication(self, src, event), ...
        };
      
      %  Create figure object
      % ------------------------------------------------------------------------
      buttonWidth = 140;
      buttonHeight = 20;

      self.mainWindow = figure('Visible', 'off', ...
        'NumberTitle', 'off', ...
        'ToolBar', 'none', ...
        'MenuBar', 'none', ...
        'Resize', 'off', ...
        'Position', [0, 0, buttonWidth, buttonHeight*size(self.buttonTitles, 2)]);

      % Assign the GUI a name to appear in the window title.
      self.mainWindow.Name = 'VFSP';
      
      % Move the main window to the upper left corner of the screen.
      movegui(self.mainWindow, 'northwest')

      %  Create pushbuttons and assign callback
      % ------------------------------------------------------------------------
      topmostButtonTop = self.mainWindow.Position(4);
      
      currentButtonDimension ...
          = [1, topmostButtonTop - buttonHeight + 1, buttonWidth, buttonHeight];
     
      for i = 1:size(self.buttonTitles, 2)
        uicontrol ('Style', 'pushbutton', ...
          'FontWeight', 'bold', ...
          'HorizontalAlignment', 'left', ...
          'String', self.buttonTitles{i}, ...
          'Position', currentButtonDimension, ...
          'Callback', self.buttonCallbacks{i});
     
        currentButtonDimension = currentButtonDimension + ...
            [0 -buttonHeight 0 0];
      end
      
      % Make the GUI visible.
      self.mainWindow.Visible = 'on';
    
      % Initialize preferences.
      markersCount = size (self.markerDefaults, 1);
      self.pref_markersEnabled = zeros (1, markersCount);
      for i = 1 : markersCount
        self.pref_markersEnabled (i) = self.markerDefaults{i, 1};
      end
      
      eventCount = 20;
      self.pref_eventStrings = cell (eventCount, 1);
      for i = 1 : eventCount
        self.pref_eventStrings {i} = sprintf ('Untitled event #%d', i);
      end 
      
      self.pref_coinMarkerSelectionCount = 3;
      self.pref_diameterCoin = 23.5;

      self.documents = [];
      
      % Load preferences.
      % If a preference file exists, loading the file will override
      % the default settings above.
      % Otherwise, the default settings are valid.
      self.loadPreferences ();
      
    end




    % --------------------------------------------------------------------------
    %
    %  Method: savePreferences
    %
    %  This function saves preferences into a .mat file.
    %
    % --------------------------------------------------------------------------
    function savePreferences (self)
      preferencesFile = 'vfsp_preferences.mat';
      
      vfspVersion = self.version();
      coinMarkerSelectionCount = ...
          self.pref_coinMarkerSelectionCount;
      diameterCoin = self.pref_diameterCoin;
      markersEnabled = self.pref_markersEnabled;
      eventStrings = self.pref_eventStrings;
      
      save (preferencesFile, ...
            'vfspVersion', ...
            'coinMarkerSelectionCount', ...
            'diameterCoin', ...
            'markersEnabled', ...
            'eventStrings' );
      
    end
 

      
    
    % --------------------------------------------------------------------------
    %
    %  Method: removeDocument
    %
    %  This function removes a document handle from the documents array.
    %
    % --------------------------------------------------------------------------
    function removeDocument (self, docHandle)
      countDocuments = size (self.documents, 2);
      newDocuments = [];
      for i = 1:countDocuments 
        if self.documents(i) == docHandle 
          continue;

        else 
          newDocuments = [newDocuments, self.documents(i)];

        end 
      end 

      self.documents = newDocuments; 

    end




  end % of public methods
  
  
  
 
  % ----------------------------------------------------------------------------
  %
  %                      P R I V A T E    M E T H O D S
  %
  % ----------------------------------------------------------------------------
  methods (Access = private)
    % --------------------------------------------------------------------------
    %
    %  Method: loadPreferences
    %
    %  This function loads preferences stored, if there exists one.
    %
    % --------------------------------------------------------------------------
    function loadPreferences (self)
      preferencesFile = 'vfsp_preferences.mat';
      if exist (preferencesFile, 'file') == 2
        load (preferencesFile, ...
              'vfspVersion', ...
              'coinMarkerSelectionCount', ...
              'diameterCoin', ...
              'markersEnabled', ...
              'eventStrings' );
        
        self.pref_coinMarkerSelectionCount = ...
            coinMarkerSelectionCount;
        self.pref_diameterCoin = diameterCoin;
        self.pref_markersEnabled = markersEnabled;
        self.pref_eventStrings = eventStrings;
      end
    end
  
      
    
    
    
    % --------------------------------------------------------------------------
    % 
    %  Method: openDocument
    %
    %  This function opens a window.
    %
    % --------------------------------------------------------------------------
    function openDocument (self, src, event)
      newDocumentId = vfspDoc (self);
      if newDocumentId.movieFileName ~= 0
        self.documents = [self.documents, newDocumentId];
      end 
    end




    % --------------------------------------------------------------------------
    %
    %  Method: saveWorkspace
    %
    %  This function opens a save dialog box, and saves current workspace to a
    %  Matlab .mat file.
    %
    % --------------------------------------------------------------------------
    function saveWorkspace (self, src, event)
      [file, path] = uiputfile ('*.mat', 'Save Marker Data As');

      if file == 0
        return;
      end

      fullPath = strcat (path, file)
      save (fullPath);
    end
   

    

    % --------------------------------------------------------------------------
    % 
    %  Method: showPreferencesDialog 
    %
    %  This function displays a preference dialog. 
    %
    % --------------------------------------------------------------------------
    function showPreferencesDialog (self, src, event)
      vfspPref (self);
    end 

  
  

    % --------------------------------------------------------------------------
    %
    %  Method: showAboutDialog
    %
    %  This callback function displays about dialog.
    %
    % --------------------------------------------------------------------------
    function showAboutDialog (self, src, event)
     % Create a dialog
      dialogWidth = 400;
      dialogHeight = 120;
      dialogWindow = dialog (...
        'WindowStyle', 'modal', ...
        'Name', 'About VFSP', ...
        'Resize', 'off', ...
        'Visible', 'off', ...
        'Position', [0 0 dialogWidth dialogHeight], ...
        'ButtonDownFcn', '');
      
      % Text strings
      uicontrol (dialogWindow, ...
        'Style', 'text', ...
        'String', 'VIDEO FLUOROSCOPY POST-PROCESSOR', ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'Position', [0 90 dialogWidth 20]);
      
      uicontrol (dialogWindow, ...
        'Style', 'text', ...
        'String', 'Seoul National University Hospital', ...
        'HorizontalAlignment', 'center', ...
        'Position', [0 70 dialogWidth 20]);
      
      versionString = sprintf ('Version: %.2f', self.version());
      uicontrol (dialogWindow, ...
        'Style', 'text', ...
        'String', versionString, ...
        'HorizontalAlignment', 'center', ...
        'Position', [0 50 dialogWidth 20]);
      
      uicontrol (dialogWindow, ...
        'Style', 'text', ...
        'String', 'Development by Changmook Chun @ KIST', ...
        'HorizontalAlignment', 'center', ...
        'Position', [0 30 dialogWidth 20]);
      
      uicontrol (dialogWindow, ...
        'Style', 'text', ...
        'String', 'Copyright (c) 2015. All rights reserved.', ...
        'HorizontalAlignment', 'center', ...
        'Position', [0 10 dialogWidth 20]);
      
      % Place the dialog at the center of display.
      movegui (dialogWindow, 'center');

      % Show the dialog
      set (dialogWindow, 'Visible', 'on');
    end

    
    
    

    % --------------------------------------------------------------------------
    % 
    %  Method: quitApplication
    %
    %  This function quits VFS application.
    %
    % --------------------------------------------------------------------------
    function quitApplication (self, src, event)

      % To Do:
      %  Ask all open documents to save and close.
      documents = self.documents;
      countDocuments = size (documents, 2);
      for i = 1:countDocuments 
        answer = documents(i).closeDocument ([], []);

        if answer == false % A document cancels quitting the application.
          return;
        end
      end

      close ();
    end




  end % of private methods
  
end % of classdef
