classdef vfspPref < handle
%
%  vfspPref
%
%  Preference window of VFS (Video FluoroScopy) analyzer.


  %
  %  Properties
  %
  properties

    %
    %  handles
    %
    app   % main application object
    
    markerCheckboxes  % Check boxes of the markers in preferences dialog
    eventTable        % Table view to display and edit events
  end % of properties
  
  

  % ----------------------------------------------------------------------------
  %
  %                          P U B L I C    M E T H O D S
  %
  % ----------------------------------------------------------------------------
  methods
    % --------------------------------------------------------------------------
    %
    %  Method: vfspPref
    %
    %  This function constructs and initializes a vfs preference window 
    %  object.
    %
    % --------------------------------------------------------------------------
    function self = vfspPref (mainApp)

      self.app = mainApp;
      
      % Create a dialog
      dialogWidth = 600;
      dialogHeight = 500;
      dialogWindow = dialog (...
        'WindowStyle', 'modal', ...
        'Name', 'VFSP Preferences', ...
        'Resize', 'off', ...
        'Visible', 'off', ...
        'Position', [0 0 dialogWidth dialogHeight], ...
        'ButtonDownFcn', '');

      columnWidth = 200;
      controlHeight = 20;
      controlOffsetV = 10;
      controlPosX = 10;
      controlPosY = dialogHeight;
      
      % Number of frames with coin markers
      % ------------------------------------------------------------------------
      % Place a popup menu with its label.
      controlWidth = dialogWidth - 220;
      controlPosY = controlPosY - controlHeight - controlOffsetV;
      uicontrol (dialogWindow, ...
        'Style', 'text', ...
        'String', 'Number of frames to pick up coin markers :', ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'right', ...
        'Position', [controlPosX  controlPosY  controlWidth  controlHeight]);

      controlWidth = dialogWidth - 500;
      controlPosX = dialogWidth - 100;
      uicontrol (dialogWindow, ...
        'Style', 'popup', ...
        'String', {'3', '4', '5', '6'}, ...
        'Value', self.app.pref_coinMarkerSelectionCount - 2, ...
        'Position', [controlPosX  controlPosY  controlWidth  controlHeight], ...
        'Callback', {@(src, event)coinMarkerPopupSelected(self, src, event)});

      
      % Diameter of a coin
      % ------------------------------------------------------------------------
      % Place a text edit field with its label.
      controlPosX = 10;
      controlPosY = controlPosY - controlHeight - controlOffsetV;
      controlWidth = dialogWidth - 220;
      uicontrol (dialogWindow, ...
        'Style', 'text', ...
        'String', 'Diameter of coin :', ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'right', ...
        'Position', [controlPosX  controlPosY  controlWidth  controlHeight]);

      controlPosX = dialogWidth - 100;
      controlWidth = dialogWidth - 510;
      uicontrol (dialogWindow, ...
        'Style', 'edit',...
        'String', num2str(self.app.pref_diameterCoin), ...
        'Position', [controlPosX  controlPosY  controlWidth  controlHeight],...
        'Callback', {@(src, event)coinDiameterEdited(self, src, event)});

      
      % Markers 
      % ------------------------------------------------------------------------
      % Place checkboxes 
      controlPosX = 10;
      baseOffset = 60;
      markersCount = size (self.app.markerDefaults, 1);
      
      % Set default selection, marker names, initial values, and relationship
      d = {markersCount, 2};
      
      for i = 1:markersCount
        % if self.app.markerDefaults{i,1}
        if self.app.pref_markersEnabled (i) == 1
          d(i,1) = num2cell(true);
        else 
          d(i,1) = num2cell(false);
        end
       
        d(i,2) = strcat('<html><font color="#', ...
          self.app.markerDefaults(i,3), ...
          self.app.markerDefaults(i,4), ...
          self.app.markerDefaults(i,5), '">', ...
          self.app.markerDefaults(i,2), '</font></html>');
      end
       
      markerSelectionLabel = uicontrol (dialogWindow, ...
        'Style', 'text', ...
        'String', 'Select markers to pick up', ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', ...
        'Position', [controlPosX ...
          baseOffset + controlHeight*markersCount ...
          columnWidth ...
          controlHeight]);

      self.markerCheckboxes = [];
      for i = 1:markersCount
        checkboxHandle = uicontrol (dialogWindow, ...
            'Style', 'checkbox', ...
            'Value', d{i,1}, ...
            'String', d{i,2}, ...
            'Position', [controlPosX ...
              baseOffset + controlHeight*(markersCount - i) ...
              columnWidth ...
              controlHeight]);
        self.markerCheckboxes = [self.markerCheckboxes checkboxHandle];
      end
      
      
      % Event table
      % ------------------------------------------------------------------------
      
      % Table data
      columnName = {'Events'};
      data = self.app.pref_eventStrings;
      % eventsCount = size (self.app.preferences.eventStrings, 1);
      % data = cell(eventsCount, 1);
      % for i = 1 : eventsCount 
      %   data{i} = self.app.preferences.eventStrings (i);
      % end 
      
      % Table view
      controlPosX = columnWidth + 10;
      controlPosY = baseOffset;

      self.eventTable = uitable (dialogWindow, ...
                            'ColumnName', columnName, ...
                            'Data', self.app.pref_eventStrings, ...
                            'ColumnEditable', [true], ...
                            'ColumnWidth', {350});
      
      self.eventTable.Position(1:2) = [controlPosX  controlPosY];
      self.eventTable.Position(3:4) = self.eventTable.Extent(3:4);
               
      
      % Close button
      % ------------------------------------------------------------------------
      buttonWidth = 100;
      uicontrol (dialogWindow, ...
        'Style', 'pushbutton', ...
        'String', 'OK', ...
        'Position', [(dialogWidth-buttonWidth)/2 20 buttonWidth 25], ...
        'Callback', {@(src, event)closePreferencesDialog(self, src, event)});
    

      % Place the dialog at the center of display.
      movegui (dialogWindow, 'center');

      % Show the dialog
      set (dialogWindow, 'Visible', 'on');

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
    %  Method: closePreferencesDialog 
    %
    %  This callback function is called when the OK button in the dialog is 
    %  clicked.
    %
    % --------------------------------------------------------------------------
    function closePreferencesDialog (self, src, event)
      % Save markers enabled status
      for i = 1:size(self.markerCheckboxes, 2)
        val = get (self.markerCheckboxes(i), 'Value');

        if val == 1
          % self.app.markerDefaults (i, 1) = num2cell(true);
          self.app.pref_markersEnabled (i) = 1;

        else 
          % self.app.markerDefaults (i, 1) = num2cell(false);
          self.app.pref_markersEnabled (i) = 0;

        end 
      end

      % Save event strings 
      self.app.pref_eventStrings = self.eventTable.Data;      
      
      self.app.savePreferences ();
      
      close (gcbf);
    end




    % --------------------------------------------------------------------------
    %
    %  Method: coinMarkerPopupSelected 
    %
    %  This callback function is called when user selects one item in 
    %  coinMarkerSelectionCountPopup popup menu.
    %
    % --------------------------------------------------------------------------
    function coinMarkerPopupSelected (self, src, event)
      % self.app.coinMarkerSelectionCount = src.Value + 2;
      self.app.pref_coinMarkerSelectionCount = src.Value + 2;
    end




    % --------------------------------------------------------------------------
    %
    %  Method: coinDiameterEdited
    %
    %  This callback function is called when user edits the diameter of coin
    %  text edit.
    %
    % --------------------------------------------------------------------------
    function coinDiameterEdited (self, src, event)
      diameter = str2num (src.String);
      % self.app.diameterCoin = diameter;
      self.app.pref_diameterCoin = diameter;
    end
    

    
    
  end % of private methods
  
end % of classdef
