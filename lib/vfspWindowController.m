classdef vfspWindowController < windowController

properties
  app
  doc

  dualViewController

  currentFrameIndex    % the index of the frame shown
  selectedMarkerIndex  % marker currently selected

  %
  % UI controls (Buttons)
  %
  buttonTitles
  buttonCallbacks
  buttons
  saveButtonIndex

  %
  % UI controls (Spinning indicator)
  %
  % spinningIndicator

  %
  % UI controls (Checkbox)
  %
  checkboxCopyMarkers      % checkbox object to choose whether to copy markers or not
  checkboxIgnoreSmoothed   % checkbox object to choose raw or smoothed trajectory
  checkboxMarkersToAnimate % checkboxes to animate movement
  checkboxAdjustContrast   % checkbox object to toggle adjustment of contrast
  checkboxManCont          % checkbox object to control the contrast manually

  %
  % UI controls (Table)
  %
  markerTable       % table view to display the markers
  activeRowIndex    % index of the row where mouse position will be written

  %
  % UI controls (misc)
  %
  sliderTime        % slider object to move forward/backward
  minFrameLabel     % text label showing the min frame label
  maxFrameLabel     % text label showing the max frame label
  currentFrameField % text label showing current frame label
  sliderContrast    % slider object to control contrast
  frameExplorerLabel
  markerTableLabel
  markerSize = 4;

  %
  % UI layout parameters
  %
  baseMargin = 5;
  leftPaneWidth       % Width of left pane
  rightPaneWidth      % Width of right pane

  imageView     % axis object to display the video
  thumbnailView % axis object to display the thumbnail of the video
  magnification % magnification of the movie image
  imageHandle

  markersDrawn  % handles of markers drawn
  edgesDrawn    % handles of edges drawn
  edgeMarkerLookup % 1st column: head marker, 2nd column: tail marker indices

end


methods
  function self = vfspWindowController (doc)
    self@windowController ();
    self.app = doc.app;
    self.doc = doc;
    self.window = [];
    self.dualViewController = [];

    self.selectedMarkerIndex = 0;  % No marker is active yet.
    self.currentFrameIndex = 0;

    % Set title and callbacks of buttons
    self.buttonTitles = { ...
      'Auto Track (Exp)', ...
      '-', ...
      'Mark Event...', ...
      'Smoothing...', ...
      '-', ...
      'Plot...', ...
      'Superimposing Plot...', ...
      'Animate Movement...', ...
      '-', ...
      'Save Data As...', ...
      'Load Data...', ...
      'Export...' ...
      };

    self.buttonCallbacks = { ...
      @(src, event)trackMarkers(self, src, event), ...
      '', ...
      @(src, event)markEvent(self, src, event), ...
      @(src, event)smoothTrajectories(self, src, event), ...
      '', ...
      @(src, event)plotTrajectories(self, src, event), ...
      @(src, event)plotSuperimposing(self, src, event), ...
      @(src, event)createAnimationWindow(self, src, event), ...
      '', ...
      @(src, event)saveDataToMatFile(self, src, event), ...
      @(src, event)loadDataFromMatFile(self, src, event), ...
      @(src, event)exportToFile(self, src, event) ...
      };

    self.saveButtonIndex = 7; % To change the button title accordingly.

  end

  %%
  %  createWindow
  %
  %  This method creates a window for the animation of the markers.
  %
  function createWindow (self)
    % Create a window at full screen size
    % scrsz = get(groot,'ScreenSize');
    % screenWidth = scrsz(3);
    % screenHeight = scrsz(4);

    self.createWindow@windowController (1024, 768);

    % Modify the properties of the window created by the superclass method.
    set (self.window, 'NumberTitle', 'off');
    set (self.window, 'ToolBar', 'none');
    set (self.window, 'MenuBar', 'none');
    set (self.window, 'Pointer', 'crosshair');

    % Associate callback functions.
    set (self.window, 'KeyPressFcn', @(src, event)processKeyDown (self, src, event));

    % --------------------------------------------------------------------------
    % First, create table view, because the width of the marker table determines
    % the width of the left pane.

    % Column names and column format
    columnname = {'', '', 'Name', 'u', 'v'};
    columnformat = {'char', 'logical', 'char', 'numeric', 'numeric'};

    % Set default selection, marker names, initial values, and relationship
    d = {size(self.app.markerDefaults, 1), 5};

    for i = 1:size(self.app.markerDefaults, 1)
      d(i, 1) = {''};

      % if self.app.markerDefaults{i, 1}
      if self.app.pref_markersEnabled (i)
        d(i, 2) = num2cell(true);
      else
        d(i, 2) = num2cell(false);
      end

      d(i, 3) = strcat('<html><font color="#', ...
        self.app.markerDefaults(i, 3), ...
        self.app.markerDefaults(i, 4), ...
        self.app.markerDefaults(i, 5), '">', ...
        self.app.markerDefaults(i, 2), '</font></html>');
      d(i, 4) = num2cell(0);
      d(i, 5) = num2cell(0);
    end

    % Create marker table
    self.markerTable = uitable(self.window, ...
      'Data', d, ...
      'ColumnName', columnname, ...
      'ColumnFormat', columnformat, ...
      'ColumnEditable', [false true false false false], ...
      'ColumnWidth', {12, 20, 100, 35, 35}, ...
      'FontSize', 10, ...
      'CellSelectionCallback', ...
        {@(src, event)cellSelected(self, src, event)}, ...
      'CellEditCallback', ...
        {@(src, event)cellEdited(self, src, event)}, ...
      'RowName',[]);

    % Set width and height of the table.
    tableWidth = self.markerTable.Extent(3);
    tableHeight = self.markerTable.Extent(4);

    self.markerTable.Position(3) = tableWidth;
    self.markerTable.Position(4) = tableHeight;
    % End of the creation of the table.

    % Set left and right pane widths.
    self.leftPaneWidth = tableWidth;
    self.rightPaneWidth = 160;

    %
    %  Create views
    %

    %  Left pane:
    self.thumbnailView = axes ('Parent', self.window, ...
      'Units', 'pixels', ...
      'Box', 'on', ...
      'Color', [.5 .5 .9], ...
      'XTick', [], 'YTick', []);

    % Place a frame explorer with its label.
    self.frameExplorerLabel = uicontrol (self.window, ...
      'Style', 'text', ...
      'FontWeight', 'bold', ...
      'HorizontalAlignment', 'left', ...
      'String', 'Frame Explorer :');

    self.sliderTime = uicontrol (self.window, ...
      'Style', 'slider', ...
      'Min', 1, 'Max', self.doc.frameCount, 'Value', 1, ...
      'SliderStep', [1/self.doc.frameCount  self.doc.frameRate/self.doc.frameCount], ...
      'Callback', @(src, event)sliderTimeClicked(self, src, event));

    self.maxFrameLabel = uicontrol(self.window, ...
      'Style', 'text', ...
      'String', strcat ('/  ', num2str(self.doc.frameCount)));

    self.currentFrameField = uicontrol(self.window, ...
      'Style', 'edit', ...
      'String', '1', ...
      'Callback', @(src, event)frameIndexEdited(self, src, event));

    % Busy spinning indicator
    % try
        % % R2010a and newer
        % iconsClassName = 'com.mathworks.widgets.BusyAffordance$AffordanceSize';
        % iconsSizeEnums = javaMethod ('values',iconsClassName);
        % SIZE_16X16 = iconsSizeEnums (1);  % (1) = 16x16,  (2) = 32x32
        % self.spinningIndicator = com.mathworks.widgets.BusyAffordance (SIZE_16X16, '');  % icon, label
    % catch
        % % R2009b and earlier
        % redColor   = java.awt.Color(1,0,0);
        % blackColor = java.awt.Color(0,0,0);
        % self.spinningIndicator = com.mathworks.widgets.BusyAffordance (redColor, blackColor);
    % end
    % self.spinningIndicator.setPaintsWhenStopped (true);  % default = false
    % self.spinningIndicator.useWhiteDots (false);         % default = false (true is good for dark backgrounds)

    % Place a checkbox for 'copy markers'
    self.checkboxCopyMarkers = uicontrol (self.window, ...
      'Style', 'checkbox', ...
      'Value', 1, ...
      'String', 'Copy markers to new frame');

    % Place a checkbox for 'ignore smoothed traj'
    self.checkboxIgnoreSmoothed = uicontrol (self.window, ...
      'Style', 'checkbox', ...
      'Value', 0, ...
      'String', 'Ignore smoothed trajectory');

    % Place label for the marker table.
    self.markerTableLabel = uicontrol (self.window, ...
      'Style', 'text', ...
      'FontWeight', 'bold', ...
      'HorizontalAlignment', 'left', ...
      'String', 'Markers :');

    %  Center pane:
    self.imageView = axes ('Parent', self.window, ...
      'Units', 'pixels', ...
      'Box', 'on', ...
      'Color', [.9 .5 .5], ...
      'XTick', [], 'YTick', []);

    %  Right pane:

    % Place a checkbox for 'Enhance contrast'
    self.checkboxAdjustContrast = uicontrol (self.window, ...
      'Style', 'checkbox', ...
      'Value', 0, ...
      'String', 'Enhance contrast', ...
      'Callback', @(src, event)adjustContrast(self, src, event));

    self.checkboxManCont = uicontrol (self.window, ...
      'Style', 'checkbox', ...
      'Value', 0, ...
      'String', 'Manually', ...
      'Enable', 'off', ...
      'Callback', @(src, event)adjustContrast(self, src, event));

    self.sliderContrast = uicontrol (self.window, ...
      'Style', 'slider', ...
      'Enable', 'off', ...
      'Min', 0, 'Max', 10, 'Value', 1, ...
      'Callback', @(src, event)adjustContrast(self, src, event));
    addlistener (self.sliderContrast, 'Value', 'PostSet', @(src, event)adjustContrast(self, src, event));

    % Create pushbuttons and assign callback
    buttons = [];

    for i = 1:size(self.buttonTitles, 2)
      if self.buttonTitles{i} ~= '-' % Draw buttons only
        button = uicontrol ('Style', 'pushbutton', ...
                            'FontWeight', 'bold', ...
                            'HorizontalAlignment', 'left', ...
                            'String', self.buttonTitles{i}, ...
                            'Callback', self.buttonCallbacks{i});
        self.buttons = [self.buttons button];
      end

    end
    % END of the creation of views.

    % Create a DualViewController and assign the views to be controlled.
    % During the creation, the constructor of the dual view controller adjusts the main
    % image view to accommodate the space required for the magnification box and scroll bars.
    self.dualViewController = vfspDualViewController (self, self.imageView, self.thumbnailView);

    self.layoutWindow ();

    % Load and display the first image frame.
    % self.currentFrameIndex = 1;
    % self.displayFrameImageLoadingMarkersToTable ();
  end


  %%
  %  determineImageViewSize
  %
  %  This function determines the size of the main image view
  %  to fit to the window size given.
  %
  function determineImageViewSize (self)
    windowWidth = self.window.Position (3);
    windowHeight = self.window.Position (4);

    % Set margins around image view of the window.
    leftPaneWidth = self.leftPaneWidth;
    rightPaneWidth = self.rightPaneWidth;

    imageViewWidth = windowWidth - 4*self.baseMargin - leftPaneWidth - rightPaneWidth;
    imageViewHeight = windowHeight - 2*self.baseMargin;

    self.imageView.Position(3) = imageViewWidth;
    self.imageView.Position(4) = imageViewHeight;

    self.app.log (sprintf ('vfspWindowController::determineImageViewSize (): image view = [%d %d %d %d]', ...
      self.imageView.Position(1), self.imageView.Position(2), ...
      self.imageView.Position(3), self.imageView.Position(4)));
  end


  %%
  %  closeWindow
  %
  %  This method asks the document object to close the document.
  %  If the user cancels the closing of the document, the document object
  %  returns 'false'.  Then the document window should not be closed.
  %  If the document object returns 'true', this function closes the document window.
  %
  function closeWindow (self)
    docWillBeClosed = self.doc.closeDocument (self);

    if docWillBeClosed
      self.closeWindow@windowController ();
    end
  end


  %%
  %  resizeWindow
  %
  %  This method re-calculate the layout of the window.
  %
  function resizeWindow (self)
    self.app.log (sprintf ('resizeWindow (): window size = %d x %d', ...
      self.window.Position(3), self.window.Position(4)));
    self.layoutWindow ();
    self.dualViewController.drawViews ();
  end


  %%
  %  drawOverlay
  %
  %  This function is draws edges and markers
  %
  function drawOverlay (self)
    self.drawEdges ();
    self.drawMarkers ();
  end


  %%
  %  setBusy
  %
  %  This function spins the busy indicator.
  %
  function setBusy (self)
    % self.spinningIndicator.start;
  end


  %%
  %  setIdle
  %
  %  This function stops the busy indicator.
  %
  function setIdle (self)
    % self.spinningIndicator.stop;
  end


  %%
  %  setMouseClickCallback
  %
  %  This function sets callback function for the image view for the
  %  mouse clicked event.
  %
  function setMouseClickCallback (self)
    % Set callback function for mouse button down event.
    set (self.imageView.Children, 'ButtonDownFcn', @(src, event)mouseClicked(self, src, event));
  end


  %%
  %  displayFrameImageLoadingMarkersToTable
  %
  %  This function loads frame image and its associated markers which
  %  correspond to current frame index.
  %
  function displayFrameImageLoadingMarkersToTable (self)
    self.loadCurrentMarkersToTable ();

    % Find the first enabled row.
    firstEnabledRow = 0;
    for i = 1 : size (self.app.markerDefaults, 1)
      if self.markerTable.Data {i, 2} == 1
        firstEnabledRow = i;
        break;
      end
    end

    % Activate the first row enabled.
    self.activateRow (firstEnabledRow);

    % Load image.
    ih = self.doc.loadFrameImage (self.currentFrameIndex);

    % Display the image.  This method call also redraws the markers and edges.
    self.dualViewController.replaceImage (ih);
  end


  %%
  %  loadCurrentMarkersToTable
  %
  %  This function loads marker data from 'marker' array to the data of
  %  current marker table.
  %
  function loadCurrentMarkersToTable (self)

    % Load marker data from model object to table view.
    current = self.currentFrameIndex;
    for i = 1 : size(self.app.markerDefaults, 1)
      self.markerTable.Data {i, 4} = ...
        self.doc.markers.(self.app.markerDefaults{i, 7})(1, current);
      self.markerTable.Data {i, 5} = ...
        self.doc.markers.(self.app.markerDefaults{i, 7})(2, current);
    end

    % Check whether current frame is registered to the indices of the frames
    % with coin markers.
    indices = find (self.doc.frameIndicesWithCoinMarkers == current);

    % Current frame contains coin markers.
    if size (indices, 2) > 0
      self.markerTable.Data (1, 2) = num2cell(true);
      self.markerTable.Data (2, 2) = num2cell(true);

    else
      % Number of frames with coin markers are smaller than threshold.
      if size (self.doc.frameIndicesWithCoinMarkers, 2) < ...
         self.app.pref_coinMarkerSelectionCount

        self.markerTable.Data (1, 2) = num2cell(true);
        self.markerTable.Data (2, 2) = num2cell(true);

      else % Enough number of coin markers picked up.
        self.markerTable.Data (1, 2) = num2cell(false);
        self.markerTable.Data (2, 2) = num2cell(false);

        self.markerTable.Data (1, 4) = num2cell (0);
        self.markerTable.Data (1, 5) = num2cell (0);

        self.markerTable.Data (2, 4) = num2cell (0);
        self.markerTable.Data (2, 5) = num2cell (0);
      end

    end
  end


  %%
  %  activateRow
  %
  %  This function activates the row with the index given.
  %  The active row is where the position of the next mouse click will be
  %  written.
  %
  function activateRow (self, index)
    % Remove the indicator ('>') in all the rows.
    for i = 1:size(self.markerTable.Data, 1)
      self.markerTable.Data {i, 1} = '';
    end
    self.activeRowIndex = 0;

    % Save the index of the active row and show the indicator.
    if index > 0
      self.activeRowIndex = index;
      self.markerTable.Data {index, 1} = '>';
    end
  end


  %%
  %  saveCurrentMarkerTableToModel
  %
  %  This function saves current markers to markers array.
  %
  function saveCurrentMarkerTableToModel (self)
    % Store time.
    idx = self.currentFrameIndex;
    % currentTime = (idx - 1)/self.frameRate;
    % self.markers.time(idx) = currentTime;

    % Copy marker data from table view to model object.
    for i = 1:size(self.app.markerDefaults, 1)
      self.doc.markers.(self.app.markerDefaults{i, 7})(1, idx) = ...
        self.markerTable.Data {i, 4};
      self.doc.markers.(self.app.markerDefaults{i, 7})(2, idx) = ...
        self.markerTable.Data {i, 5};
    end

    self.doc.correctFrameIndicesWithCoinMarkers ();
  end


  %%
  %  ignoreSmoothed
  %
  %  This function returns whether the ignoreSmoothed checkbox is clicked or not.
  %
  function result = ignoreSmoothed (self)
    if self.checkboxIgnoreSmoothed.Value == 1
      result = false;
    else
      result = true;
    end
  end


  % ----------------------------------------------------------------------------
  %
  %                        G U I    C A L L B A C K S
  %
  % ----------------------------------------------------------------------------

  %%
  %  sliderTimeClicked
  %
  %  This function is called when the slider is clicked.
  %
  function sliderTimeClicked (self, src, event)
    % Save current frame markers
    self.saveCurrentMarkerTableToModel ();

    newFrameCounter = round (src.Value);
    self.shiftFrameTo (newFrameCounter);
  end


  %%
  %  frameIndexEdited
  %
  %  This callback function is called when the frame counter display
  %  is edited.
  %
  function frameIndexEdited (self, src, event)
    % val = round(str2double(src.String));
    [val, tf] = str2num (src.String);

    if tf == 1
      newFrameIndex = self.limitFrameIndex (val);

    else  % This means the conversion failed.
      % Simply keep current frame index.
      newFrameIndex = self.currentFrameIndex;
    end

    set (src, 'String', num2str (newFrameIndex));

    % Save current frame markers
    self.saveCurrentMarkerTableToModel ();

    % Shift frame.
    self.shiftFrameTo (newFrameIndex);

    % Change the value of the slider
    set (self.sliderTime, 'Value', newFrameIndex);
  end


  %%
  %  trackMarkers
  %
  %  This function calls trackMarkers method of document object.
  %  The function automatically tracks the markers given initial positions.
  %
  function trackMarkers (self, src, event)
    % Save current markers to model object.
    self.saveCurrentMarkerTableToModel ();

    self.doc.trackMarkers (self.currentFrameIndex);
  end


  %%
  %  markEvent
  %
  %  This function marks an event at current frame.
  %
  function markEvent (self, src, event)
    vfspEvent (self.doc);
  end


  %%
  %  smoothTrajectories
  %
  %  This function filters and smooths the trajectories of markers.
  %
  function smoothTrajectories (self, src, event)
    % Save current markers to model object.
    self.saveCurrentMarkerTableToModel ();

    self.doc.smoothTrajectories ();
  end


  %%
  %  plotTrajectories
  %
  %  This function plots trajectories of the markers.
  %
  function plotTrajectories (self, src, event)
    % Save current markers to model object.
    self.saveCurrentMarkerTableToModel ();

    smoothing = self.ignoreSmoothed ();
    self.doc.plotTrajectories (smoothing);
  end


  %%
  %  createAnimationWindow
  %
  %  This callback function creates animation of the markers.
  %
  function createAnimationWindow (self, src, event)
    % Save current markers to model object.
    self.saveCurrentMarkerTableToModel ();

    smoothing = self.ignoreSmoothed ();
    self.doc.createAnimationWindow (smoothing);
  end


  %%
  %  plotSuperimposing
  %
  %  This callback function creates superimposing plot.
  %
  function plotSuperimposing (self, src, event)
    % Save current markers to model object.
    self.saveCurrentMarkerTableToModel ();

    smoothing = self.ignoreSmoothed ();
    self.doc.plotSuperimposing (smoothing);
  end


  %%
  %  saveDataToMatFile
  %
  %  This function called when "Save" button is clicked.
  %
  function saveDataToMatFile (self, src, event)
    % Save current markers to model object.
    self.saveCurrentMarkerTableToModel ();

    result = self.doc.saveDataToMatFile ();

    if result == true % Saving the data to mat file was successful.
      % Mark there is unsaved change.
      self.doc.hasUnsavedChanges = false;

      % Change the title of the window.
      self.window.Name = self.doc.movieFileName;
    end
  end


  %%
  %  loadDataFromMatFile
  %
  %  This function loads markers, events, and smoothing scheme
  %  from a .mat file.
  %
  function loadDataFromMatFile (self, src, event)
    result = self.doc.loadDataFromMatFile ();

    if result == true % Data successfully loaded.
      % Change the 'string' property of the save button.
      set (self.buttons(self.saveButtonIndex), 'String', 'Save Markers');

      % Load image and draw markers.
      self.displayFrameImageLoadingMarkersToTable ();

      % Redraw markers even though it has the same image.
      self.drawOverlay ();
    end
  end


  %%
  %  exportToFile
  %
  %  This function is called by "Export" button click.
  %
  function exportToFile(self, src, event)
    % Save current markers to model object.
    self.saveCurrentMarkerTableToModel ();

    smoothing = self.ignoreSmoothed ();
    self.doc.exportToFile (smoothing);
  end


  % ----------------------------------------------------------------------------
  %
  %                       E V E N T    C A L L B A C K S
  %
  % ----------------------------------------------------------------------------

  %%
  %  processKeyDown
  %
  %  This function is called when a key press event happens in movie window.
  %
  function processKeyDown (self, src, event)
    % left & right arrows, left & right brackets
    if strcmp (event.Key, 'rightarrow') || strcmp (event.Key, 'leftarrow') ...
      || strcmp (event.Key, 'rightbracket') || strcmp (event.Key, 'leftbracket')

      % Distinguish keys.
      if strcmp (event.Key, 'rightarrow')
        index = self.currentFrameIndex + 1;
      elseif strcmp (event.Key, 'leftarrow')
        index = self.currentFrameIndex - 1;
      elseif strcmp (event.Key, 'rightbracket')
        index = self.currentFrameIndex + self.frameRate;
      elseif strcmp (event.Key, 'leftbracket')
        index = self.currentFrameIndex - self.frameRate;
      end

      % Calculate new frame counter by saturating if needed.
      newFrameIndex = self.limitFrameIndex (index);

      % Save current frame markers
      self.saveCurrentMarkerTableToModel ();

      % Shift frame.
      self.shiftFrameTo (newFrameIndex);

      % Change the value of the slider
      set (self.sliderTime, 'Value', newFrameIndex);

    % backspace
    elseif strcmp (event.Key, 'backspace') || strcmp (event.Key, 'delete')

      self.deleteMarkerSelected ();

    end
  end


  %%
  %  mouseClicked
  %
  %  This callback function is called when a mouse button is clicked in the
  %  image display axes.
  %
  function mouseClicked (self, src, event)
    if strcmp (self.window.SelectionType, 'normal')
      % Get the position (x and y) of the mouse pointer in image coordinate.
      [u, v] = self.getCurrentPositionInImage ();

      self.app.log (sprintf('[Mouse Clicked] in image: (%d, %d)', u, v));

      index = 0;
      if self.selectedMarkerIndex == 0 % There is no marker selected.
        index = self.activeRowIndex;

      else % There is a marker selected. Modify it.
        index = self.selectedMarkerIndex;

      end

      if index ~= 0
        self.writeMarkerToRow (index, u, v);
        self.activateNextEnabledRow ();

        % Draw markers
        self.updateMarkerDrawn (index, u, v);

        self.doc.markUnsavedChanges ();
      end
    end
  end


  %%
  %  mouseMoved
  %
  %  This callback is called when a mouse moves in the main figure window.
  %
  function mouseMoved (self, src, event)
    % Get the position (x and y) of the mouse pointer in image coordinate.
    [u, v] = self.getCurrentPositionInImage ();

    self.writeMarkerToRow (self.selectedMarkerIndex, u, v);

    % Update markers.
    self.updateMarkerDrawn (self.selectedMarkerIndex, u, v);

  end


  %%
  %  cellEdited
  %
  function cellEdited (self, src, event)
    % Find the index of selected row.
    selectedRow = event.Indices (1);
    selectedCol = event.Indices (2);

    if selectedCol == 2 % Checkbox is clicked.
                        % Enable or disable the selected row accordingly.

      if src.Data{selectedRow, 2} == 0  % The selected row is being disabled.
        % Disable the row setting the coordinates of the marker to 0.
        if self.movieFileName ~= 0
          self.writeMarkerToRow (selectedRow, 0, 0);
          self.updateMarkerDrawn (selectedRow, 0, 0);
        end
        selectedRow = 0;

      else % The selected row is being enabled.
        self.activateRow (selectedRow);

      end
    end
  end


  %%
  %  cellSelected
  %
  %  This callback function is called when a cell is selected in the uitable
  %  which shows the markers.
  %
  function cellSelected (self, src, event)
    if size (event.Indices, 1) == 0
      return;
    end

    % Find the index of selected row.
    selectedRow = event.Indices (1);
    selectedCol = event.Indices (2);

    if selectedCol ~= 2 % Cell other than the checkbox is clicked.
                        % Activate the row, if the row is enabled.

      if src.Data{selectedRow, 2} == 1  % The selected row is enabled.
        self.activateRow (selectedRow);
      end
    end
  end


  %%
  %  adjustContrast
  %
  %  This callback function is called when checkboxAdjustContrast is clicked.
  %
  function adjustContrast (self, src, event)
    if src == self.checkboxAdjustContrast
      if self.checkboxAdjustContrast.Value == 1 % Enabling contrast adjustment
        self.checkboxManCont.Enable = 'on';
        self.sliderContrast.Enable = 'on';

      else % Disabling contrast adjustment
        self.checkboxManCont.Enable = 'off';
        self.sliderContrast.Enable = 'off';

      end
    end

    self.dualViewController.drawScrollView ();
  end


  % ----------------------------------------------------------------------------
  %
  %
  %
  % ----------------------------------------------------------------------------

  %%
  %  setFrameIndex
  %
  %  This function displays current frame index in the text edit field
  %  below the slider.
  %
  function setFrameIndex (self, val)
    set (self.currentFrameField, 'String', num2str(val));
  end


  %%
  %  limitFrameIndex
  %
  %  This function limits the frame counter so that it is always between
  %  1 and the maximum number of frames.
  %
  function indexLimited = limitFrameIndex (self, index)
    if index < 1
      indexLimited = 1;
    elseif index >= self.doc.frameCount
      indexLimited = self.doc.frameCount;
    else
      indexLimited = index;
    end
  end


  %%
  %  shiftFrameTo
  %
  %  This function changes current frame.
  %
  function shiftFrameTo (self, newFrameIndex)

    % Backup current frame index.
    previousFrameIndex = self.currentFrameIndex;

    self.setFrameIndex (newFrameIndex);
    self.currentFrameIndex = newFrameIndex;

    % Copy markers from the previous frame to new one.
    if self.checkboxCopyMarkers.Value == 1
      self.doc.copyMarkersToCurrentFrame (previousFrameIndex);
    end

    % Load image if needed and display
    self.displayFrameImageLoadingMarkersToTable ();

  end


  %%
  %  deleteMarkerSelected
  %
  %  This function deletes the data from active marker.
  %
  function deleteMarkerSelected (self)
    if self.selectedMarkerIndex > 0
      % Update markers.
      self.writeMarkerToRow (self.selectedMarkerIndex, 0, 0);
      self.updateMarkerDrawn (self.selectedMarkerIndex, 0, 0);

      % Reset active marker index.
      self.selectedMarkerIndex = 0;

      set (self.window, 'WindowButtonMotionFcn', '');

      self.doc.markUnsavedChanges ();
    end
  end


  %%
  %  writeMarkerToRow
  %
  %  This function enters the position of mouse pointer clicked to the
  %  row with the index given.
  %
  function writeMarkerToRow (self, index, x, y)
    % Write the position data given.
    self.markerTable.Data {index, 4} = x;
    self.markerTable.Data {index, 5} = y;

    % Mark that the raw trajectory of the marker is editted.
    % (Re-smoothing required later.)
    marker_key = self.app.markerDefaults{index, 7};
    if self.doc.smoothingParameters.(marker_key)(1) > 0
      self.doc.smoothingParameters.(marker_key)(1) = -1 * self.doc.smoothingParameters.(marker_key)(1);
    end

    self.doc.markUnsavedChanges ();
  end


  %%
  %  activateNextEnabledRow
  %
  %  This function activate the next row which is enabled.
  %  If the current active row is the last row in the table, this function
  %  sets the activeRowIndex to 0.
  %
  function activateNextEnabledRow (self)
    % If activeRowIndex is 0, this function does nothing.
    if self.activeRowIndex == 0
      return;
    end

    % Find the next row enabled.
    for i = self.activeRowIndex + 1 : size(self.markerTable.Data, 1)
    if self.markerTable.Data {i, 2} == 1
        self.activeRowIndex = i;
        self.activateRow (i);
        return;
      end
    end

    % There is no row enabled after the active row.
    self.activeRowIndex = 0;
    self.activateRow (0);
  end


  %%
  %  drawMarkers
  %
  %  This function draws markers in accordance to the color format.
  %
  function drawMarkers (self)
    self.markersDrawn = [];
    for i = 1 : size (self.app.markerDefaults, 1)
      % Extract color settings for the marker.
      markerColorCode = [num2str(self.app.markerDefaults {i, 3}), ' ', ...
                         num2str(self.app.markerDefaults {i, 4}), ' ', ...
                         num2str(self.app.markerDefaults {i, 5})];
      edgeColor = (sscanf (markerColorCode, '%x').')/256;
      faceColor = 'white';

      % Specify the coordinates of the marker.
      u = self.markerTable.Data {i, 4};
      v = self.markerTable.Data {i, 5};
      [x, y] = self.dualViewController.imageToViewCoordinate (u, v);

      % Set shape or the marker.
      kind = self.discriminateMarker (i);

      if kind == 0
        markerShape = 'o';
      elseif kind == 1
        markerShape = '^';
      else
        markerShape = 'v';
      end

      % Set visibility of the marker.
      if x == 0 || y == 0 || self.markerTable.Data {i, 2} == 0
        visibility = 'off';
      else
        visibility = 'on';
      end

      handleToMarkerDrawn = line (...
        'XData', x, 'YData', y, ...
        'Marker', markerShape, ...
        'MarkerEdgeColor', edgeColor, ...
        'MarkerFaceColor', faceColor, ...
        'MarkerSize', self.markerSize, ...
        'Visible', visibility);
      set (handleToMarkerDrawn, ...
           'ButtonDownFcn', @(src, event)selectMarker(self, src, event));
      self.markersDrawn = [self.markersDrawn handleToMarkerDrawn];
    end
  end


  %
  %  discriminateMarker
  %
  %  This function discriminates the marker.
  %  It returns 1 for head marker, 0 for stand alone marker, and
  %  -1 for tail marker.
  %
  function kind = discriminateMarker (self, index)
    relatedMarkerIndex = self.app.markerDefaults {index, 6};

    if relatedMarkerIndex == 0 % Stand alond marker.
      kind = 0;

    elseif relatedMarkerIndex > index % The marker is head marker.
      kind = 1;

    else % The marker is tail marker.
      kind = -1;

    end
  end


  %
  %  updateMarkerDrawn
  %
  %  This function updates marker specified and its corresponding edges.
  %
  function updateMarkerDrawn (self, index, u, v)

    markerBeingDeleted = false;
    visibility = 'on';

    if u == 0 && v == 0 % This marker is being deactivated.
      markerBeingDeleted = true;
      visibility = 'off';
    end

    % Update marker shape.
    if index == self.selectedMarkerIndex
      markerShape = 'square';
      markerFaceColor = 'none';
      markerSize = 12;

    else
      markerSize = self.markerSize;
      markerFaceColor = 'white';
      kind = self.discriminateMarker (index);

      if kind == 0
        markerShape = 'o';
      elseif kind == 1
        markerShape = '^';
      elseif kind == -1
        markerShape = 'v';
      end
    end

    % Convert image coordinate to axes (view) coordinate.
    [x, y] = self.dualViewController.imageToViewCoordinate (u, v);

    % Update the marker with the coordinates given, shape, and visibility.
    set (self.markersDrawn (index), ...
         'Marker', markerShape, ...
         'XData', x, 'YData', y, ...
         'MarkerSize', markerSize, ...
         'MarkerFaceColor', markerFaceColor, ...
         'Visible', visibility);

    % Find the edge being updated by the marker.
    edgeIndex = find (self.edgeMarkerLookup == index);
    if isempty (edgeIndex) % There is no edge related to the marker being updated.
      % Do nothing.
    else
      countEdges = size (self.edgeMarkerLookup, 1);
      headMarker = true;

      if edgeIndex > countEdges
        edgeIndex = edgeIndex - countEdges;
        headMarker = false;
      end

      xx = get (self.edgesDrawn (edgeIndex), 'XData');
      yy = get (self.edgesDrawn (edgeIndex), 'YData');

      if headMarker
        xx(1) = x;
        yy(1) = y;
      else
        xx(2) = x;
        yy(2) = y;
      end

      % Set line style.  If any marker is invalid, the edge will be invisible.
      lineStyle = '-';

      headMarkerId = self.edgeMarkerLookup (edgeIndex, 1);
      tailMarkerId = self.edgeMarkerLookup (edgeIndex, 2);

      u_head = self.markerTable.Data {headMarkerId, 4};
      v_head = self.markerTable.Data {headMarkerId, 5};

      u_tail = self.markerTable.Data {tailMarkerId, 4};
      v_tail = self.markerTable.Data {tailMarkerId, 5};


      if markerBeingDeleted || u_head == 0 || u_tail == 0 || v_head == 0 || v_tail == 0
        lineStyle = 'none';
      end

      set (self.edgesDrawn (edgeIndex), 'XData', xx, 'YData', yy, 'LineStyle', lineStyle);
    end

  end


  %
  %  drawEdges
  %
  %  This function draws edges in accordance to the color format of markers
  %  and the connection specifications.
  %
  function drawEdges (self)
    self.edgesDrawn = [];
    self.edgeMarkerLookup = [];
    for i = 1 : size (self.app.markerDefaults, 1)
      % Examine whether a related marker is enabled.
      relatedMarkerIndex = self.app.markerDefaults {i, 6};

      if relatedMarkerIndex > i && self.markerTable.Data {i, 2} == 1 && ...
           self.markerTable.Data {relatedMarkerIndex, 2} == 1
        % This marker has a partner marker, with which defines an edge,
        % and both of them are enabled.

        % Construct edge-marker lookup table.
        self.edgeMarkerLookup = [self.edgeMarkerLookup; ...
          i relatedMarkerIndex];

        % Extract color settings for the marker.
        markerColorCode = [num2str(self.app.markerDefaults {i, 3}), ' ', ...
                           num2str(self.app.markerDefaults {i, 4}), ' ', ...
                           num2str(self.app.markerDefaults {i, 5})];
        edgeColor = (sscanf (markerColorCode, '%x').')/256;

        u_head = self.markerTable.Data {i, 4};
        u_tail = self.markerTable.Data {relatedMarkerIndex, 4};

        v_head = self.markerTable.Data {i, 5};
        v_tail = self.markerTable.Data {relatedMarkerIndex, 5};

        u = [u_head u_tail];
        v = [v_head v_tail];

        % Set line style.  If any marker is invalid, the edge will be invisible.
        lineStyle = '-';
        if u_head == 0 || u_tail == 0 || v_head == 0 || v_tail == 0 || ...
           self.markerTable.Data {i, 2} == 0 || ...
           self.markerTable.Data {relatedMarkerIndex, 2} == 0

          lineStyle = 'none';
        end

        [x_head, y_head] = self.dualViewController.imageToViewCoordinate (u_head, v_head);
        [x_tail, y_tail] = self.dualViewController.imageToViewCoordinate (u_tail, v_tail);

        x = [x_head x_tail];
        y = [y_head y_tail];

        set (self.window, 'CurrentAxes', self.imageView);
        handleToEdgeDrawn = line (...
          'XData', x, 'YData', y, ...
          'LineWidth', 2, ...
          'LineStyle', lineStyle, ...
          'Color', edgeColor);, ...
        self.edgesDrawn = [self.edgesDrawn handleToEdgeDrawn];
      end
    end
  end


  %
  %  selectMarker
  %
  %  This function is called when a mouse clicked on a marker.
  %
  function selectMarker (self, src, event)
    if self.selectedMarkerIndex == 0 % Selecting a marker.
      handle = gcbo;  % The handle of the graphics object whose callback is executing.
      [u, v] = self.dualViewController.viewToImageCoordinate (handle.XData, handle.YData);

      for i = 1 : size (self.app.markerDefaults, 1)
        if u == self.markerTable.Data {i, 4} && v == self.markerTable.Data {i, 5}  % Marker found

          self.selectedMarkerIndex = i;
          self.activateRow (i);

          % Make selected marker easy to distinguish.
          set (self.markersDrawn (self.selectedMarkerIndex), ...
               'Marker', 'square', ...
               'MarkerSize', 12, ...
               'MarkerFaceColor', 'none');

          % Associate WindowButtonMotionFcn callback.
          set (self.window, 'WindowButtonMotionFcn', @(src, event)mouseMoved(self, src, event));

          break;
        end
      end

    else % Releasing the marker selected.

      % Update marker shape.
      kind = self.discriminateMarker (self.selectedMarkerIndex);

      if kind == 0
        markerShape = 'o';
      elseif kind == 1
        markerShape = '^';
      elseif kind == -1
        markerShape = 'v';
      end

      % Recover the shape of de-selected marker.
      set (self.markersDrawn (self.selectedMarkerIndex), ...
           'Marker', markerShape, ...
           'MarkerSize', self.markerSize, ...
           'MarkerFaceColor', 'white');

      % Release selected marker.
      self.selectedMarkerIndex = 0;

      set (self.window, 'WindowButtonMotionFcn', '');

    end
  end


  %
  %  getCurrentPositionInImage
  %
  %  This function converts the current position of the mouse pointer
  %  from the image view frame to the image frame.
  %
  function [u, v] = getCurrentPositionInImage (self)
    pos = get(self.imageView, 'CurrentPoint');
    x = pos (1,1);
    y = pos (1,2);
    [u, v] = self.dualViewController.viewToImageCoordinate (x, y);
  end


end


methods (Access = protected)
  %%
  %  layoutWindow
  %
  %  This function places GUI elements.
  %
  function layoutWindow (self)
    self.app.log ('vfspWindowController::layoutWindow ()');
    self.app.log (sprintf ('  window size = %d x %d', self.window.Position(3), self.window.Position(4)));
    self.determineImageViewSize ();

    windowWidth = self.window.Position(3);
    windowHeight = self.window.Position(4);
    imageViewWidth = self.imageView.Position(3);
    imageViewHeight = self.imageView.Position(4);

    % Set margins around image view of the window.
    tableWidth = self.markerTable.Extent(3);
    leftPaneWidth = self.leftPaneWidth;
    rightPaneWidth = self.rightPaneWidth;

    %
    %  Left pane:
    %
    thumbnailWidth = leftPaneWidth;
    thumbnailHeight = thumbnailWidth * self.doc.videoObject.Height / self.doc.videoObject.Width;

    controlHOffset = self.baseMargin;
    controlVTop = windowHeight - self.baseMargin;

    set (self.thumbnailView, 'Position', ...
        [self.baseMargin, windowHeight - self.baseMargin - thumbnailHeight, ...
         thumbnailWidth, thumbnailHeight]);

    % Place a frame explorer with its label.
    controlV = controlVTop  - thumbnailHeight - 35;
    set (self.frameExplorerLabel, 'Position', [controlHOffset, controlV, leftPaneWidth, 20]);

    controlV = controlV - 20;
    set (self.sliderTime, ...
      'Min', 1, 'Max', self.doc.frameCount, 'Value', 1, ...
      'SliderStep', [1/self.doc.frameCount  30/self.doc.frameCount], ...
      'Position', [controlHOffset, controlV, leftPaneWidth, 20]);

    controlV = controlV - 20;
    set (self.maxFrameLabel, ...
      'Position', [controlHOffset + leftPaneWidth/2, controlV, 40, 20]);

    set (self.currentFrameField, ...
      'Position', [controlHOffset + leftPaneWidth/2 - 40, controlV, 40, 20]);

    % Spinning indicator
    % javacomponent (self.spinningIndicator.getComponent, ...
    %   [controlHOffset + leftPaneWidth - 40, controlV, 16, 16], self.window);

    % Place a checkbox for 'copy markers'
    controlV = controlV - 30;
    set (self.checkboxCopyMarkers, 'Position', [controlHOffset, controlV, leftPaneWidth, 12]);

    % Place a checkbox for 'ignore smoothed traj'
    controlV = controlV - 20;
    set (self.checkboxIgnoreSmoothed, 'Position', [controlHOffset, controlV, leftPaneWidth, 12]);

    % Set position of the marker table.
    controlV = controlV - 30;

    % Place label for the marker table.
    set (self.markerTableLabel, 'Position', [controlHOffset, controlV, leftPaneWidth, 20]);

    % Place the table.
    controlV = controlV - 2;
    self.markerTable.Position(1) = controlHOffset;
    self.markerTable.Position(2) = controlV - self.markerTable.Position(4);

    %
    %  Center pane:
    %
    set (self.imageView, 'Position', ...
      [2*self.baseMargin + leftPaneWidth, windowHeight - self.baseMargin - imageViewHeight, ...
       imageViewWidth, imageViewHeight]);

    %
    %  Right pane:
    %
    controlHOffset = windowWidth - self.baseMargin - rightPaneWidth;
    controlV = windowHeight - self.baseMargin - 15;

    % Place 'Enhance contrast' checkbox
    controlV = controlV - 20;
    set (self.checkboxAdjustContrast, 'Position', [controlHOffset, controlV, rightPaneWidth, 12]);

    % Place 'Manually' checkbox.  This box is indented by 10 pt.
    controlV = controlV - 20;
    set (self.checkboxManCont, 'Position', [controlHOffset + 10, controlV, rightPaneWidth, 12]);

    % Place slider control for the manual adjustment of contrast.
    controlV = controlV - 20;
    set (self.sliderContrast, 'Position', [controlHOffset, controlV, rightPaneWidth, 12]);

    % Place buttons.
    buttonWidth = rightPaneWidth;
    buttonHeight = 24;
    topmostButtonTop = controlV - 30;

    currentButtonDimension = [controlHOffset, topmostButtonTop - buttonHeight + 1, ...
           buttonWidth, buttonHeight];

    j = 1;
    for i = 1:size(self.buttonTitles, 2)
      if self.buttonTitles{i} == '-' % Enlarge vertical gap
        currentButtonDimension = currentButtonDimension + [0, -12, 0, 0];

      else % Place button
        set (self.buttons(j), 'Position', currentButtonDimension);
        currentButtonDimension = currentButtonDimension + [0, -buttonHeight - 4, 0, 0];
        j = j + 1;
      end
    end

    % Resize image view considering the scrollbars
    self.app.log ('vfspWindowController::layoutWindow ()');
    self.dualViewController.adjustLayout ();
  end

end

end
