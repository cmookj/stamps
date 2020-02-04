classdef vfspEvent < handle
%
%  vfspEvent
%
%  Event display and setting  window of VFS (Video FluoroScopy) analyzer.


  %
  %  Properties
  %
  properties

    %
    %  handles
    %
    doc    % document object

    eventTable  % Table view to display and edit events
  end % of properties

  % ----------------------------------------------------------------------------
  %
  %                          P U B L I C    M E T H O D S
  %
  % ----------------------------------------------------------------------------
  methods
    % --------------------------------------------------------------------------
    %
    %  Method: vfspEvent
    %
    %  This function constructs and initializes a vfs preference window 
    %  object.
    %
    % --------------------------------------------------------------------------
    function self = vfspEvent (theDocument)

      self.doc = theDocument;

      % Create a dialog
      dialogWidth = 470;
      dialogHeight = 450;
      dialogWindow = dialog (...
        'WindowStyle', 'modal', ...
        'Name', 'Select an Event to Mark at Current Frame', ...
        'Resize', 'off', ...
        'Visible', 'off', ...
        'Position', [0 0 dialogWidth dialogHeight], ...
        'ButtonDownFcn', '');

      controlHeight = 20;
      controlOffsetV = 10;

      % Event table
      % ------------------------------------------------------------------------

      % Table data
      columnName = {'Events', 'Frame #'};
      rowCount = size (self.doc.app.pref_eventStrings, 1);
      data = cell (rowCount, 2);
      data (:, 1) = self.doc.app.pref_eventStrings;
      for i = 1 : rowCount
        data (i, 2) = num2cell (self.doc.eventFrames (i));
      end

      % Table view
      controlPosX = 10;
      controlPosY = 70;

      self.eventTable = ...
          uitable (dialogWindow, ...
                   'ColumnName', columnName, ...
                   'Data', data, ...
                   'ColumnEditable', [false true], ...
                   'ColumnWidth', {350, 60}, ...
                   'CellSelectionCallback', ...
                   {@(src, event)cellSelected(self,src, event)});

      self.eventTable.Position(1:2) = [controlPosX  controlPosY];
      self.eventTable.Position(3:4) = self.eventTable.Extent(3:4);

      % Close button
      buttonWidth = 100;
      uicontrol (dialogWindow, ...
        'Style', 'pushbutton', ...
        'String', 'OK', ...
        'Position', [(dialogWidth-buttonWidth)/2 20 buttonWidth 25], ...
        'Callback', {@(src, event)closeDialog(self, src, event)});

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

    %%
    %  cellSelected
    %
    %  This callback function is called when a row is selected.
    %
    function cellSelected (self, src, event)
      if size (event.Indices, 1) == 0
        return;
      end 

      % Find the index of selected row.
      selectedRow = event.Indices (1);
      selectedCol = event.Indices (2);
      
      % Set the frame number of selected event to current frame
      % index, only if the event is selected. 
      % Clicking the frame number does not change the frame number.
      if selectedCol == 1
        % Display.
        self.eventTable.Data (selectedRow, 2) = num2cell (self.doc.currentFrameIndex);
      end

    end


    %%
    %  closeDialog
    %
    %  This callback function is called when the OK button in the dialog is
    %  clicked.
    %
    function closeDialog (self, src, event)
      eventCount = size (self.doc.eventFrames, 1);

      for i = 1 : eventCount
        self.doc.eventFrames (i) = ...
            self.eventTable.Data {i, 2};
      end

      close (gcbf);
    end


  end % of private methods
  
end % of classdef
