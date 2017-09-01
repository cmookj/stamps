classdef vfspDoc < handle
  %
  %  Properties
  %
  properties

    % handles
    %
    app      % main application object
    window   % figure object to display movie (window)

    %
    % UI controls (Buttons)
    %
    buttonTitles
    buttonCallbacks
    buttons
    saveButtonIndex

    %
    % UI controls (Scrollbars)
    %
    horizontalScrollbar % Horizontal scrollbar under the movie view
    verticalScrollbar   % Vertical scrollbar right to the movie view

    %
    % UI controls (Checkbox)
    %
    copyMarkersCheckbox % checkbox object to choose whether to copy markers or not 
    ignoreSmoothedCheckbox % checkbox object to choose raw or smoothed trajectory
    markersToAnimateCheckbox % checkboxes to animate movement
    clearViewCheckbox % checkbox object to toggle clear view (increase contrast)

    %
    % UI controls (Table)
    %
    markerTable       % table view to display the markers 
   
    %
    % UI controls (misc)
    %
    timeSlider        % slider object to move forward/backward
    minFrameLabel     % text label showing the min frame label
    maxFrameLabel     % text label showing the max frame label
    currentFrameField % text label showing current frame label
   
    %
    % Model object (Video related members)
    %
    videoObject        % video object (result of reading of video file)
    movieFileName      % file name of the video
    moviePathName      % path to the video file
    movieData     % movie data structure
    frameCount    % the number of all the frames in the movie
    frameRate     % the frame rate of the movie 
    magnification % magnification of the movie image 
    
    imageView     % axis object to display the video 
    markersDrawn  % handles of markers drawn
    edgesDrawn    % handles of edges drawn 
    edgeMarkerLookup % 1st column: head marker, 2nd column: tail marker indices
    
    animationView % axis object to animate trajectories
   
    %
    % Model object (Markers related members)
    %
    hasUnsavedChanges    % flag to indicate whether there are unsaved changes
    markers              % array of the trajectories of the markers 
    markersSmoothed      % array of the smoothed trajectories of the markers 
    markersTransformed   % trajectories of markers coordinate-transformed using C2-C4
    smoothingParameters  % smoothing parameters
    selectedMarkerIndex  % marker currently selected 
    activeRowIndex       % index of the row where mouse position will be written
    currentFrameIndex    % the index of the frame shown 

    markerCheckboxes         % Check boxes of the markers in preferences dialog
    frameIndicesWithCoinMarkers % Array of frame indices with coin markers.

    dataFile  % .mat file to save data (markers, events, smoothing parameters)
    
    eventFrames % Array to store the frame counter of events 
  end
  
  

  % ----------------------------------------------------------------------------
  %
  %                          P U B L I C    M E T H O D S
  %
  % ----------------------------------------------------------------------------
  methods
    % --------------------------------------------------------------------------
    %
    %  Method: vfspDoc
    %
    %  This function constructs and initializes a vfspDoc 
    %  object.
    %
    % --------------------------------------------------------------------------
    function self = vfspDoc (theApp)
     
      self.app = theApp;

      %  Set title and callbacks of buttons
      self.buttonTitles = { ...
        'Mark Event...', ...
        'Smoothing...', ...
        '-', ...
        'Plot...', ...
        'Superimposing Plot...', ...
        'Animate Movement...', ...
        '-', ...
        'Save Data As...', ...
        'Load Data...', ...
        'Export...'
        };

      self.buttonCallbacks = { ...
        @(src, event)markEvent(self, src, event), ...
        @(src, event)smoothTrajectories(self, src, event), ...
        @(src, event)doNothing(self, src, event), ...
        @(src, event)plotTrajectories(self, src, event), ...
        @(src, event)plotSuperimposing(self, src, event), ...
        @(src, event)createAnimationWindow(self, src, event), ...
        @(src, event)doNothing(self, src, event), ...
        @(src, event)saveDataToMatFile(self, src, event), ...
        @(src, event)loadDataFromMatFile(self, src, event), ...
        @(src, event)exportToTextFile(self, src, event)
        };
     
      self.saveButtonIndex = 6; % To change the button title accordingly.

      % Get screen size
      scrsz = get(groot,'ScreenSize');
      screenWidth = scrsz(3);
      screenHeight = scrsz(4);
 

      % Initialize properties
      self.currentFrameIndex = 1;
      self.frameCount = 640;

      self.movieFileName = '';
      self.moviePathName = '';
      self.selectedMarkerIndex = 0;  % No marker is active yet.
      self.dataFile = '';  % No output file specified.


      % Show a file open dialog
      [filename, pathname] = uigetfile( ...
        {'*.avi; *.mpg; *.mp4; *.m4v; *.mov', ...
        'Video Files (*.avi, *.mpg, *.mp4, *.m4v, *.mov)'; ...

        '*.avi', ...
        'AVI video files (*.avi)'; ...

        '*.mpg', ...
        'MPEG-1 video files (*.mpg)'; ...

        '*.mp4; *.m4v', ...
        'MPEG-4, including H.264 encoded video files (*.mp4, *.m4v)'; ...

        '*.mov', ...
        'Apple QuickTime Movie (*.mov)'}, ...
        'Pick a video file', 'MultiSelect', 'off');
      self.movieFileName = filename;
      self.moviePathName = pathname;
        
      if (filename ~= 0) % A movie file is selected and opened.

        % Create window for movie view and assign callback
        % ----------------------------------------------------------------------
        self.window = figure ('Visible', 'off', ...
          'NumberTitle', 'off', ...
          'ToolBar', 'none', ...
          'MenuBar', 'none', ...
          'Pointer', 'crosshair', ...
          'Position', [0, 0, 1280, 800]);

        % Associate callback functions.
        set (self.window, ...
          'KeyPressFcn', {@(src, event)processKeyDown(self, src, event)}, ...
          'CloseRequestFcn', {@(src, event)closeDocument(self, src, event)});

        % Read video and obtain its information
        % ---------------------------------------------------------------------
        videoObject = VideoReader (strcat(pathname, filename));
        
        % Get information of the video file
        lastFrame = read(videoObject, inf);
        time = videoObject.CurrentTime;
        duration = videoObject.Duration;
        self.frameCount = videoObject.NumberOfFrames - 1; % Prevent the access
                                                          % to the last frame.
        self.frameRate = videoObject.FrameRate;
        
        videoHeight = videoObject.Height;
        videoWidth = videoObject.Width;


        %  Create table view
        % ----------------------------------------------------------------------
        
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
                      
        % Create the uitable
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
        

        % Set margins around image view of the window.
        % Note that right and bottom margins should be large enough to
        % accommodate scrollbars as required.
        baseMargin = 10;
        topMargin = baseMargin;
        bottomMargin = baseMargin;
        leftMargin = baseMargin;
        rightMargin = baseMargin + tableWidth + baseMargin;


        % Calculate image view size.
        % ----------------------------------------------------------------------
        %
        %        .-------------------------------------------------.
        %        |                 top margin (fixed)              |
        %        |           .----------------------.              |
        %        |           |                      |              |
        %        |   left    |     image            |   right      |
        %        |   margin  |     view             |   margin     |
        %        |   (fixed) |     (scalable)       |   (fixed)    |
        %        |           |                      |              |
        %        |           |                      |              |
        %        |           '----------------------'              |
        %        |                 bottom margin (fixed)           |
        %        |                                                 |
        %        '-------------------------------------------------'
        %
        % Note that the width of the window is the sum of the widths of
        % image view, left and right margins.
        % Because the height of the video is typically greater than that of 
        % table, this code only considers the height of the image view and
        % margins.
        availableWidth = screenWidth - leftMargin - rightMargin;
        availableHeight = screenHeight - topMargin - bottomMargin - 100;

        minimumRequiredHeight = 750;
        if availableHeight < minimumRequiredHeight % Too short screen 
          % Show warning 
          mode = struct('WindowStyle', 'modal', 'Interpreter', 'tex');
          errordlg({'{\bf The screen is too short.}', ...
                    '  Some contents will be cropped out.', ...
                    '  How about using a larger display?'}, ...
                    'Too short a screen', mode);
        end

        availableAspectRatio = availableWidth / availableHeight;

        videoAspectRatio = videoWidth / videoHeight;
        imageViewHeight = videoHeight;
        imageViewWidth = videoWidth;
        imageScaleFactor = 1.0;

        % Decide what to compare between width and height.
        % ---------------------------------------------------------------------
        % If the screen is wider in aspect than the movie window,
        % constrain the height of the movie window.
        % Otherwise, constrain the width of the movie window.
        %
        if availableAspectRatio > videoAspectRatio % Taller video
          % Constrain the height of the movie window.
          if availableHeight >= videoHeight % There's enough space for video
            imageScaleFactor = 1.0;
            imageViewHeight = videoHeight;
            imageViewWidth = videoWidth;

          else % Not enough space available.  Scale the video.
            imageScaleFactor = availableHeight / videoHeight;
            imageViewHeight = availableHeight;
            imageViewWidth = round (imageScaleFactor * videoWidth);

          end

        else % Wider video
          % Constrain the width of the movie window.
          if availableWidth >= videoWidth % Enough space for video
            imageScaleFactor = 1.0;
            imageViewWidth = videoWidth;
            imageViewHeight = videoHeight;

          else % Not enough space for video.  Scale the video.
            imageScaleFactor = availableWidth / videoWidth;
            imageViewWidth = availableWidth;
            imageViewHeight = round (imageScaleFactor * videoHeight);

          end
        end

        mainHeight = imageViewHeight;
        if imageViewHeight < 750
          mainHeight = 750;
        end 

        windowHeight = mainHeight + topMargin + bottomMargin;
        windowWidth = imageViewWidth + leftMargin + rightMargin;

        % Set position of the window.
        set (self.window, 'Position', [0, 0, windowWidth, windowHeight]);

        % ----------------------------------------------------------------------
        % Create and place image view.
        self.imageView = axes ('Parent', self.window, ...
          'Units', 'pixels', ...
          'Box', 'on', ...
          'XTick', [], 'YTick', [], ...
          'XLim', [0 imageViewWidth], ...
          'YLim', [0 imageViewHeight], ...
          'Position', ...
            [leftMargin, windowHeight - topMargin - imageViewHeight, ...
             imageViewWidth, imageViewHeight]);

        % Clear current imageView
        cla (self.imageView);
       

        % Place GUI controls
        % ----------------------------------------------------------------------
        controlHOffset = leftMargin + imageViewWidth + baseMargin;
        controlVTop = windowHeight - topMargin;
       
        % Place scrollbars 
        % scrollbarThickness = 15;
        % self.horizontalScrollbar = uicontrol (self.window, ...
        %   'Style', 'slider', ...
        %   'Min', 1, 'Max', videoWidth, 'Value', 1, ...
        %   'SliderStep', [1  40], ...
        %   'Position', [leftMargin, bottomMargin - scrollbarThickness, ...
        %      mainWidth, scrollbarThickness], ...
        %   'Callback', {@(src, event)scrollImage(self, src, event)});

        % self.verticalScrollbar = uicontrol (self.window, ...
        %   'Style', 'slider', ...
        %   'Min', 1, 'Max', videoHeight, 'Value', 1, ...
        %   'SliderStep', [1  40], ...
        %   'Position', [leftMargin + mainWidth, bottomMargin, ...
        %     scrollbarThickness, mainHeight], ...
        %   'Callback', {@(src, event)scrollImage(self, src, event)});

        
        % ----------------------------------------------------------------------
        %  Right Column of Controls
        %

        % Place a frame explorer with its label.
        controlV = controlVTop - 15;
        uicontrol (self.window, ...
          'Style', 'text', ...
          'FontWeight', 'bold', ...
          'HorizontalAlignment', 'left', ...
          'String', 'Frame Explorer :', ...
          'Position', [controlHOffset, controlV, tableWidth, 20]);

        controlV = controlV - 20;
        self.timeSlider = uicontrol (self.window, ...
          'Style', 'slider', ...
          'Min', 1, 'Max', self.frameCount, 'Value', 1, ...
          'SliderStep', [1/self.frameCount  30/self.frameCount], ...
          'Position', [controlHOffset, ...
                       controlV, ...
                       tableWidth, 20], ...
          'Callback', {@(src, event)timeSliderClicked(self, src, event)});
        
        % Attach text labels showing the max/min time
        controlV = controlV - 20;
        self.maxFrameLabel = uicontrol(self.window, ...
          'Style', 'text', ...
          'String', strcat ('/', num2str(self.frameCount)), ...
          'Position', ...
            [controlHOffset + tableWidth/2, ...
             controlV, ...
             40, 20]);
        
        self.currentFrameField = uicontrol(self.window, ...
          'Style', 'edit', ...
          'String', '1', ...
          'Position', ...
            [controlHOffset + tableWidth/2 - 40, ...
             controlV, ...
             40, 20], ...
          'Callback', {@(src, event)frameCounterEdited(self, src, event)});

        
        % Place a checkbox for 'copy markers'
        self.copyMarkersCheckbox = ...
            uicontrol (self.window, ...
                       'Style', 'checkbox', ...
                       'Value', 1, ...
                       'String', 'Copy markers to new frame', ...
                       'Position', [controlHOffset, controlVTop - 80, ...
                            tableWidth, 12]);
        
        % Place a checkbox for 'ignore smoothed traj'
        self.ignoreSmoothedCheckbox = ...
            uicontrol (self.window, ...
                       'Style', 'checkbox', ...
                       'Value', 0, ...
                       'String', 'Ignore smoothed trajectory', ...
                       'Position', [controlHOffset, controlVTop - 100, ...
                            tableWidth, 12]);

        % Place a checkbox for 'clear view'
        self.clearViewCheckbox = ...
            uicontrol (self.window, ...
                       'Style', 'checkbox', ...
                       'Value', 0, ...
                       'String', 'Clear view', ...
                       'Position', [controlHOffset, controlVTop - 120, ...
                            tableWidth, 12], ...
                       'Callback', @(src, event)clearViewCallback(self, src, event));
        
        % Create pushbuttons and assign callback
        buttons = [];
        buttonWidth = tableWidth;
        buttonHeight = 24;
        topmostButtonTop = controlVTop - 140;
        
        currentButtonDimension ...
            = [controlHOffset, ...
               topmostButtonTop - buttonHeight + 1, ...
               buttonWidth, buttonHeight];
       
        for i = 1:size(self.buttonTitles, 2)
          if self.buttonTitles{i} == '-' % Enlarge vertical gap
            currentButtonDimension = currentButtonDimension + ...
              [0, -12, 0, 0];
            
          else % Draw actual button
            button = uicontrol ('Style', 'pushbutton', ...
                                'FontWeight', 'bold', ...
                                'HorizontalAlignment', 'left', ...
                                'String', self.buttonTitles{i}, ...
                                'Position', currentButtonDimension, ...
                                'Callback', self.buttonCallbacks{i});
            self.buttons = [self.buttons button];
            
            currentButtonDimension = currentButtonDimension + ...
              [0, -buttonHeight - 4, 0, 0];
          end
          
        end

        % ----------------------------------------------------------------------
        % Set position of the marker table.
        
        controlV = currentButtonDimension(2) - 20;
        
        % Place label for the marker table.
        uicontrol (self.window, ...
          'Style', 'text', ...
          'FontWeight', 'bold', ...
          'HorizontalAlignment', 'left', ...
          'String', 'Markers :', ...
          'Position', [controlHOffset, controlV, tableWidth, 20]);
        
        % Place the table.
        controlV = controlV - 2;
        self.markerTable.Position(1) = controlHOffset;
        self.markerTable.Position(2) = controlV - self.markerTable.Position(4);

        
        % Create movie structure
        self.movieData = ...
          struct (...
          'cdata', zeros(videoHeight, videoWidth, 1, 'uint8'), ...
          'colormap', [], ...
          'loaded', 0 );
        
        % Read video file into video object
        self.videoObject = VideoReader (strcat(pathname, filename));
        self.currentFrameIndex = 1;
        
        
        % ----------------------------------------------------------------------
        %  Define struct to store marker data
        %
        self.markers = struct;  %  Create a struct with no fields.

        % Time sequence.
        self.markers.('time') = ... 
          [0:(1./self.frameRate):(self.frameCount - 1)*(1./self.frameRate)];

        self.markersSmoothed.('time') = ... 
          [0:(1./self.frameRate):(self.frameCount - 1)*(1./self.frameRate)];
        
        % Markers (Raw data and smoothed trajectories).
        for i = 1:size(self.app.markerDefaults, 1) % Add fields according to
                                                   % the markerDefaults member
                                                   % of the app.
          self.markers.(self.app.markerDefaults{i, 7}) ...
            = zeros (2, self.frameCount); % Time series of 2 dim vector.
          self.markersSmoothed.(self.app.markerDefaults{i, 7}) ...
            = zeros (2, self.frameCount); % Time series of 2 dim vector.
        end
        % ----------------------------------------------------------------------
        
        % Events
        self.eventFrames = zeros (size (self.app.pref_eventStrings, 1), 1);

        % ----------------------------------------------------------------------
        %  Smoothing parameters.
        % 
        %    size: number of markers by 5
        %
        %    1st column: method 
        %    2nd column: parameter #1
        %    3rd column: parameter #2
        %    4th column: unused
        %    5th column: unused
        %
        %   Note that if smoothing method is -n (n: natural number),
        %   it means that re-smoothing with method n is required.
        %  
        %  Method #0
        %    Name: No smoothing
        %
        %  Method #1
        %    Name: polynomial curve fitting
        %    Parameters: degree (5 .. 15)
        %
        %  Method #2
        %    Name: Moving average 
        %    Parameters: span
        %
        %  Method #3
        %    Name: LOWESS
        %    Parameters: span
        %
        %  Method #4
        %    Name: LOESS
        %    Parameters: span
        %
        %  Method #5
        %    Name: Savitzky-Golay filter
        %    Parameters: span, degree
        %
        %  Method #6
        %    Name: Robust LOWESS
        %    Parameters: span
        %
        %  Method #7
        %    Name: Robust LOESS
        %    Parameters: span 
        %
        for i = 1 : size(self.app.markerDefaults, 1)
          self.smoothingParameters.(self.app.markerDefaults{i, 7})...
            = zeros (1, 5);
        end
        

        % There is no unsaved change yet.
        self.hasUnsavedChanges = 0;

        % Load the first frame and display it.
        loadFrameImageWithMarkers (self);
       
        % Reset variables specific to each movie file.
        self.frameIndicesWithCoinMarkers = [];
        
        % Assign the GUI a name to appear in the window title.
        self.window.Name = filename;
        
        % Move the main window to the center of the screen.
        % movegui (self.window, 'center');

        % Make imageView window current figure.
        figure (self.window);

        % Make the GUI visible.
        self.window.Visible = 'on';

      end

    end




    % --------------------------------------------------------------------------
    %
    %  Method: closeDocument
    %
    %  This function is by a close request.
    %
    % --------------------------------------------------------------------------
    function answer = closeDocument (self, src, event)
      answer = true;
      if self.hasUnsavedChanges == 1 % There are unsaved changes.
        % Bring the window to front 
        figure (self.window);

        % Ask the user whether to save the changes or not.
        message = sprintf ('There are unsaved changes with %s.', ...
                           self.movieFileName);
        choice = questdlg({message, ...
                           'Do you want to save the marker data?'}, ...
          'Unsaved Changes', ...
          'No', 'Cancel', 'Yes', 'Yes');

        % Handle response
        switch choice
          case 'Yes'
            saveDataToMatFile (self, src, event);

          case 'No'
            disp(''); % To prevent java.lang.NullPointerException error.

          case 'Cancel'
            answer = false;
            return;
        end 

      end 

      self.app.removeDocument (self);
      delete (self.window);
    end 




  end
  
  
  
 
  % ----------------------------------------------------------------------------
  %
  %                      P R I V A T E    M E T H O D S
  %
  % ----------------------------------------------------------------------------
  methods (Access = private)
    % --------------------------------------------------------------------------
    % 
    %  Method: doNothing
    %
    %  This function does nothing.
    %
    % --------------------------------------------------------------------------
    function doNothing (self, src, event)
    end
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: markEvent
    %
    %  This function marks an event at current frame.
    %
    % --------------------------------------------------------------------------
    function markEvent (self, src, event)
      vfspEvent (self);
    end 
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: saveDataToMatFile
    %
    %  This function saves current markers, events, and smoothing
    %  scheme to a .mat file.
    %
    % --------------------------------------------------------------------------
    function saveDataToMatFile (self, src, event)

      % Save current markers to model object.
      saveCurrentFrameMarkersToModel (self);

      if size(self.dataFile, 1) == 0 % No file specified yet.
        [file, path] = uiputfile ('*.mat', 'Save Marker Data As');

        if file == 0 % User didn't choose a file to save.
          return;
        end

        self.dataFile = strcat (path, file);
        set (self.buttons(self.saveButtonIndex), 'String', 'Save Data');
      end

      vfspVersion = self.app.version();
      markers = self.markers;
      smoothingParameters = self.smoothingParameters;
      markersSmoothed = self.markersSmoothed;
      
      save (self.dataFile, ...
            'vfspVersion', ...
            'markers', ...
            'smoothingParameters', ...
            'markersSmoothed');

      clearUnsavedChanges (self);
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: loadDataFromMatFile
    %
    %  This function loads markers, events, and smoothing scheme 
    %  from a .mat file.
    %
    % --------------------------------------------------------------------------
    function loadDataFromMatFile (self, src, event)
      [file, path] = uigetfile ('*.mat', 'Load Marker Data From');

      if file == 0
        return;
      end

      self.dataFile = strcat (path, file);
      load (self.dataFile, 'markers', 'vfspVersion');

      % Examine the version and data of mat file.
      if vfspVersion >= 0.51
        countFrames = size (markers.time, 2);

        if countFrames < self.frameCount % Saved sequence is shorter
          choice = questdlg({'Saved sequence is shorter than the video.', ...
                             'Would you like to load the data?', ...
                             '(The data will be loaded as long as possible.)'}, ...
                            'Shorter Sequence', 'Yes', 'No', 'Yes');

          switch choice
            case 'Yes'
              copyMarkerDataUpto (self, countFrames, markers);

            case 'No'
              return;
          end 

        elseif countFrames == self.frameCount % Same lengths
          self.markers = markers;

        elseif self.frameCount < countFrames % Saved sequence is longer
          choice = questdlg({'Saved sequence is longer than the video.', ...
                             'Would you like to load the data?', ...
                             '(The data will be truncated.)'}, ...
                            'Longer Sequence', 'Yes', 'No', 'Yes');

          switch choice
            case 'Yes'
              copyMarkerDataUpto (self, self.frameCount, markers);

            case 'No'
              return;
          end 
        end

      end % of if vfspVersion >= 0.51

      % if vfspVersion >= 0.6 && vfspVersion < 0.9
      %   load (self.dataFile, 'smoothnessParameters');
      %   self.smoothingParameters = smoothnessParameters;
      % end % of if vfspVersion >= 0.6
      
      if vfspVersion >= 0.9
        load (self.dataFile, ...
              'smoothingParameters', ...
              'markersSmoothed');
        self.smoothingParameters = smoothingParameters;
        self.markersSmoothed = markersSmoothed;
      end 
      
      % Change the 'string' property of the save button.
      set (self.buttons(self.saveButtonIndex), 'String', 'Save Markers');

      % Load image and draw markers.
      loadFrameImageWithMarkers (self);
    end 


    
    
    % --------------------------------------------------------------------------
    %
    %  Method: prepareTrajectoriesToProcess
    %
    %  This function prepares trajectories to process.
    %
    %  If 'ignoreSmoothedTrajectories' is selected, simply copy all raw 
    %  trajectories to the data to process.
    %
    %  Otherwise, this function examines every trajectory.
    %  If any of the trajectories require re-smoothing, this function opens
    %  smoothing window.
    %  If all the trajectories are either already smoothed or do not require
    %  smoothing, this function copies smoothed or raw trajectories to the data
    %  to process.
    %
    % --------------------------------------------------------------------------
    function plotData = prepareTrajectoriesToProcess (self)

      % Choose raw or smoothed trajectory to plot.
      if self.ignoreSmoothedCheckbox.Value == 1 % No smoothing required.
        % Simply copy raw trajectories.
        plotData = self.markers;

      else % Smoothing required, if necessary.

        % First, copy raw trajectories which do not require smoothing.
        for i = 1 : size (self.app.markerDefaults, 1)
          markerKey = self.app.markerDefaults {i, 7};

          if self.smoothingParameters.(markerKey)(1) == 0 % Smoothing no required.
            self.markersSmoothed.(markerKey) = self.markers.(markerKey);
          end
        end

        while self.isSmoothingRequired ()

          % Simply copy coin anterior/posterior markers without smoothing.
          % self.markersSmoothed.(self.app.markerKeyCoinAnterior) = ...
          %     self.markers.(self.app.markerKeyCoinAnterior);
          
          % self.markersSmoothed.(self.app.markerKeyCoinPosterior) = ...
          %     self.markers.(self.app.markerKeyCoinPosterior);

          % Open smoothing window.
          h = vfspSmthr (self.app, self);

          % Display an error message saying that re-smoothing required.
          mode = struct('WindowStyle', 'modal', 'Interpreter', 'tex');
          msgbox ({'{\bf Re-Smoothing Required}', ...
                   '     Some trajectories changed after last smoothing.'}, ...
                   'Smoothing Required Error', mode);

          % Wait the smoothing window to be closed.
          waitfor (h.window);

        end % of while

        plotData = self.markersSmoothed;

      end

    end
    
    
   

    % --------------------------------------------------------------------------
    %
    %  Method: isSmoothingRequired
    %
    %  This function examines all the trajectories whether smoothing is 
    %  required or not.
    %
    % --------------------------------------------------------------------------
    function answer = isSmoothingRequired (self)
      answer = false;

      % Examine whether re-smoothing is required or not, e.g., 
      % the raw trajectories changed without re-smoothing.
      for i = 3 : size (self.app.markerDefaults, 1)
        if self.smoothingParameters.(self.app.markerDefaults{i, 7})(1) < 0
          answer = true;

          % No need to examine further.
          break;
        end
      end
    end

    
    

    % --------------------------------------------------------------------------
    %
    %  Method: exportToTextFile
    %
    %  This function exports data to a text file.
    %
    % --------------------------------------------------------------------------
    function exportToTextFile(self, src, event)
      
      % Ask user to choose a file to export data.
      [file, path] = uiputfile ('*.txt', 'Export Marker Data As');

      if file == 0 % User didn't choose a file to save.
        return;
      end
      
      exportFile = strcat (path, file);
      
      % Save current markers to model object.
      saveCurrentFrameMarkersToModel (self);

      % Choose raw or smoothed trajectory to plot.
      plotData = self.prepareTrajectoriesToProcess ();

      % Coordinate transformation of markers.
      self.transformMarkers (plotData);
                    
      % Time difference.
      dt = 1./self.frameRate;
      
      % Hyoid bone
      key = self.app.markerKeyHyoidAnterior;
      [vd_hyoid, hd_hyoid, md_hyoid] = ...
          self.maximalDisplacementOfMarker (self.markersTransformed.(key));
      [vv_hyoid, hv_hyoid, mv_hyoid] = ...
          self.maximalVelocityOfMarker (self.markersTransformed.(key), dt);
      
      
      % Larynx 
      key = self.app.markerKeyVocalFoldAnterior;
      [vd_larynx, hd_larynx, md_larynx] = ...
          self.maximalDisplacementOfMarker (self.markersTransformed.(key));
      [vv_larynx, hv_larynx, mv_larynx] = ...
          self.maximalVelocityOfMarker (self.markersTransformed.(key), dt);
      
      
      % Arytenoid 
      key = self.app.markerKeyArytenoid;
      [vd_arytenoid, hd_arytenoid, md_arytenoid] = ...
          self.maximalDisplacementOfMarker (self.markersTransformed.(key));
      [vv_arytenoid, hv_arytenoid, mv_arytenoid] = ...
          self.maximalVelocityOfMarker (self.markersTransformed.(key), dt);
      
        
      % UES 
      key1 = self.app.markerKeyUESAnterior;
      key2 = self.app.markerKeyUESPosterior;
      [max_ues, mean_ues] = self.distanceBtwnMarkers (self.markersTransformed.(key1), ...
                                                 self.markersTransformed.(key2));
      
      
      % C2-C4 distance
      key1 = self.app.markerKeyC2;
      key2 = self.app.markerKeyC4;
      [max_c2c4, mean_c2c4] = self.distanceBtwnMarkers (self.markersTransformed.(key1), ...
                                                   self.markersTransformed.(key2));
      
      
      % Epiglottis 
      horizontalMirror = [-1 0; 0 1];
      key_b = self.app.markerKeyEpiglottisBase;
      key_t = self.app.markerKeyEpiglottisTip;
      delta = horizontalMirror * (self.markersTransformed.(key_t) ...
                                  - self.markersTransformed.(key_b));
      epiglotticAngle = atan2 (delta(2, :), delta(1, :));

      % Clockwise rotation is positive for Epiglottis angle (NOT mathematical).
      epglts_angle_from_initial = -(epiglotticAngle - epiglotticAngle(1)); 
      epglts_angle_from_y = -(epiglotticAngle - pi/2);
      
      max_epglts_angle_from_initial = max (epglts_angle_from_initial) * 180/pi;
      max_epglts_angle_from_y = max (epglts_angle_from_y) * 180/pi;
      
      v_max_epglts = max (self.approximateVelocity (epglts_angle_from_initial, dt));
      v_max_epglts = v_max_epglts * 180/pi;
      
      % Bolus
      key = self.app.markerKeyFoodBolusHead;
      [vv_bolus, hv_bolus, mv_bolus] = ...
          self.maximalVelocityOfMarker (-self.markersTransformed.(key), dt);
            
            
      % Export data to file.
      FID = fopen (exportFile, 'w');
      
      % fprintf (FID, '__DISTANCE_[mm]__\n\n');
      
      % fprintf (FID, '_HYOID_BONE_\n');
      % fprintf (FID, 'Vertical_displacement: %f\n', vd_hyoid);
      % fprintf (FID, 'Horizontal_displacement: %f\n', hd_hyoid);
      % fprintf (FID, '2D_maximal_displacement: %f\n\n', md_hyoid);
      
      % fprintf (FID, '_LARYNX_\n');
      % fprintf (FID, 'Vertical_displacement: %f\n', vd_larynx);
      % fprintf (FID, 'Horizontal_displacement: %f\n', hd_larynx);
      % fprintf (FID, '2D_maximal_displacement: %f\n\n', md_larynx);
      
      % fprintf (FID, '_ARYTENOID_\n');
      % fprintf (FID, 'Vertical_displacement: %f\n', vd_arytenoid);
      % fprintf (FID, 'Horizontal_displacement: %f\n', hd_arytenoid);
      % fprintf (FID, '2D_maximal_displacement: %f\n\n', md_arytenoid);
      
      % fprintf (FID, '_UES_\n');
      % fprintf (FID, 'Maximal_UES_opening: %f\n\n', max_ues);
      
      % fprintf (FID, '_C2-C4_\n');
      % fprintf (FID, 'Mean_C2-C4: %f\n\n', mean_c2c4);
      
      % fprintf (FID, '_EPIGLOTTIS_\n');
      % fprintf (FID, 'Maximal_tilt_angle_from_initial_position: %f\n', ...
               % max_epglts_angle_from_initial);
      % fprintf (FID, 'Maximal_tilt_angle_from_y_axis: %f\n\n', ...
               % max_epglts_angle_from_y);
      
      % fprintf (FID, '\n__VELOCITY_[mm/sec, deg/sec]__\n\n');
      
      % fprintf (FID, '_HYOID_BONE_\n');
      % fprintf (FID, 'Vertical_velocity: %f\n', vv_hyoid);
      % fprintf (FID, 'Horizontal_velocity: %f\n', hv_hyoid);
      % fprintf (FID, '2D_maximal_velocity: %f\n\n', mv_hyoid);
      
      % fprintf (FID, '_LARYNX_\n');
      % fprintf (FID, 'Vertical_velocity: %f\n', vv_larynx);
      % fprintf (FID, 'Horizontal_velocity: %f\n', hv_larynx);
      % fprintf (FID, '2D_maximal_velocity: %f\n\n', mv_larynx);
      
      % fprintf (FID, '_ARYTENOID_\n');
      % fprintf (FID, 'Vertical_velocity: %f\n', vv_arytenoid);
      % fprintf (FID, 'Horizontal_velocity: %f\n', hv_arytenoid);
      % fprintf (FID, '2D_maximal_velocity: %f\n\n', mv_arytenoid);
      
      % fprintf (FID, '_EPIGLOTTIS_\n');
      % fprintf (FID, 'Maximal_angular_velocity: %f\n\n', v_max_epglts);
      
      % fprintf (FID, '_BOLUS_\n');
      % fprintf (FID, 'Maximal_velocity: %f\n\n', mv_bolus);
     
      % Displacements
      fprintf (FID, '%f    ', vd_hyoid);
      fprintf (FID, '%f    ', hd_hyoid);
      fprintf (FID, '%f    ', md_hyoid);
      
      fprintf (FID, '%f    ', vd_larynx);
      fprintf (FID, '%f    ', hd_larynx);
      fprintf (FID, '%f    ', md_larynx);
      
      fprintf (FID, '%f    ', vd_arytenoid);
      fprintf (FID, '%f    ', hd_arytenoid);
      fprintf (FID, '%f    ', md_arytenoid);
      
      fprintf (FID, '%f    ', max_ues);
      
      fprintf (FID, '%f    ', mean_c2c4);
      
      fprintf (FID, '%f    ', max_epglts_angle_from_initial);
      fprintf (FID, '%f    ', max_epglts_angle_from_y);
     
      % Velocities
      fprintf (FID, '%f    ', vv_hyoid);
      fprintf (FID, '%f    ', hv_hyoid);
      fprintf (FID, '%f    ', mv_hyoid);
      
      fprintf (FID, '%f    ', vv_larynx);
      fprintf (FID, '%f    ', hv_larynx);
      fprintf (FID, '%f    ', mv_larynx);
      
      fprintf (FID, '%f    ', vv_arytenoid);
      fprintf (FID, '%f    ', hv_arytenoid);
      fprintf (FID, '%f    ', mv_arytenoid);
      
      fprintf (FID, '%f    ', v_max_epglts);
      
      fprintf (FID, '%f  \n', mv_bolus);

      fclose (FID);
    end
    



    % --------------------------------------------------------------------------
    %
    %  Method: maximalDisplacementOfMarker
    %
    %  This function calculates vertical, horizontal, and 2D maximal 
    %  displacements.
    %
    % --------------------------------------------------------------------------
    function [vd, hd, md] = maximalDisplacementOfMarker (self, data)
      % Vertical displacement.
      vd = max (data(2,:)) - min (data(2,:));
      
      % Horizontal displacement.
      hd = max (data(1,:)) - min (data(1,:));
      
      % 2D maximal displacement.
      firstPoint = data(:, 1);
      difference = [data(1,:) - firstPoint(1); ...
                    data(2,:) - firstPoint(2) ];
      displacement = sqrt (difference(1,:).^2 + difference(2,:).^2);
      md = max (displacement);
    end
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: maximalVelocityOfMarker
    %
    %  This function calculates vertical, horizontal, and 2D maximal 
    %  velocities.
    %
    % --------------------------------------------------------------------------
    function [mvv, mhv, mv] = maximalVelocityOfMarker (self, data, h)
      count = size(data, 2);
      
      % Vertical velocity.
      vv = self.approximateVelocity (data(2,:), h);
      mvv = max (vv);
      
      % Horizontal velocity.
      hv = self.approximateVelocity (data(1,:), h);
      mhv = max (hv);
      
      % 2D maximal velocity.
      v = sqrt (vv.^2 + hv.^2);
      mv = max (v);
    end
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: approximateVelocity
    %
    %  This function calculates approximated velocities of discrete data given.
    %
    %  This function uses two-point approximation formula at mid points:
    %
    %                  f'(x) = (f(x + h) - f(x - h)) / (2h)
    %
    %  At the both end points, it uses the following form:
    %
    %                  f'(x) = (f(x + h) - f(x)) / h
    % --------------------------------------------------------------------------
    function v = approximateVelocity (self, data, h)
      count = size (data, 2);
      v = zeros (1, count);
      
      % First point
      v(1) = (data(2) - data(1))/h;
      
      % Intermediate points
      for i = 2 : count-1
        v(i) = (data(i+1) - data(i-1))/(2*h);
      end
      
      % Last point
      v(count) = (data(count) - data(count-1))/h;
      
    end
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: distanceBtwnMarkers
    %
    %  This function calculates maximal and mean distance of markers.
    %
    % --------------------------------------------------------------------------
    function [max_d, mean_d] = distanceBtwnMarkers (self, p1, p2)
      difference = p1 - p2;
      distance = sqrt (difference(1,:).^2 + difference(2,:).^2);
      max_d = max (distance);
      mean_d = mean (distance);
    end
    
    
    
      
    % --------------------------------------------------------------------------
    % 
    %  Method: copyMarkerDataUpto
    %
    %  This function copies 'n' marker data from the input 'markers' to 
    %  self.markers.
    %
    % --------------------------------------------------------------------------
    function copyMarkerDataUpto (self, n, markers)
      % Copy time sequence.
      self.markers.('time')(1, 1:n) = markers.('time')(1, 1:n);

      % Copy marker sequences from the 1st to the nth frame.
      countMarkers = size (self.app.markerDefaults, 1);
      for i = 1 : countMarkers
        key = self.app.markerDefaults{i, 7};
        self.markers.(key)(:, 1:n) = markers.(key)(:, 1:n);
      end
    end



    
    % --------------------------------------------------------------------------
    % 
    %  Method: smoothTrajectories
    %
    %  This function filters and smooths the trajectories of markers.
    %
    % --------------------------------------------------------------------------
    function smoothTrajectories (self, src, event)

      % Save current markers to model object.
      saveCurrentFrameMarkersToModel (self);
      
      % Simply copy coin anterior/posterior markers without smoothing.
      self.markersSmoothed.(self.app.markerKeyCoinAnterior) = ...
          self.markers.(self.app.markerKeyCoinAnterior);
      
      self.markersSmoothed.(self.app.markerKeyCoinPosterior) = ...
          self.markers.(self.app.markerKeyCoinPosterior);

      vfspSmthr (self.app, self);
    end
    
    
    
      
    % --------------------------------------------------------------------------
    % 
    %  Method: plotTrajectories 
    %
    %  This function plots trajectories of the markers.
    %
    % --------------------------------------------------------------------------
    function plotTrajectories (self, src, event)

      % Save current markers to model object.
      saveCurrentFrameMarkersToModel (self);

      % Choose raw or smoothed trajectory to plot.
      plotData = self.prepareTrajectoriesToProcess ();

      % Coordinate transformation of markers.
      self.transformMarkers (plotData);

      % ------------------------------------------------------------------------

      tseq = plotData.('time');

      % Create a window for displacement plots.
      scsize = get(0, 'screensize');
      mainWindowPosition = [0.1*scsize(3) 0.07*scsize(4) 0.8*scsize(3) 0.8*scsize(4)];
      mainWindowName = sprintf('Displacements of %s', self.movieFileName);
      
      mainPlotWindow = figure ( ...
        'NumberTitle', 'off', ...
        'Position', mainWindowPosition, ...
        'Name', mainWindowName ...
        );

      
      % Hyoid vertical movement
      subplot (3, 3, 1);
      key = self.app.markerKeyHyoidAnterior;
      plot (tseq, self.markersTransformed.(key)(2, :), 'b', 'linewidth', 1.5); 
      grid on;
      ylabel ('displacement[mm]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Hyoid: vertical movement}');
      
      % Hyoid horizontal movement
      key = self.app.markerKeyHyoidAnterior;
      subplot (3, 3, 4); % Just below the subplot above.
      plot (tseq, self.markersTransformed.(key)(1, :), 'b', 'linewidth', 1.5); 
      grid on;
      ylabel ('displacement[mm]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Hyoid: horizontal movement}');
      
      % Larynx vertical movement
      subplot (3, 3, 2); 
      key = self.app.markerKeyVocalFoldAnterior;
      plot (tseq, self.markersTransformed.(key)(2, :), 'k', 'linewidth', 1.5); 
      grid on;
      ylabel ('displacement[mm]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Larynx: vertical movement}');
      
      % Larynx horizontal movement
      subplot (3, 3, 5); 
      key = self.app.markerKeyVocalFoldAnterior;
      plot (tseq, self.markersTransformed.(key)(1, :), 'k', 'linewidth', 1.5); 
      grid on;
      ylabel ('displacement[mm]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Larynx: horizontal movement}');
      
      % Arytenoid vertical movement
      subplot (3, 3, 3); 
      key = self.app.markerKeyArytenoid;
      plot (tseq, self.markersTransformed.(key)(2, :), 'k', 'linewidth', 1.5); 
      grid on;
      ylabel ('displacement[mm]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Arytenoid: vertical movement}');
      
      % Arytenoid horizontal movement
      subplot (3, 3, 6); 
      key = self.app.markerKeyArytenoid;
      plot (tseq, self.markersTransformed.(key)(1, :), 'k', 'linewidth', 1.5); 
      grid on;
      ylabel ('displacement[mm]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Arytenoid: horizontal movement}');
      
      % Epiglottic angle
      horizontalMirror = [-1 0; 0 1];
      key_b = self.app.markerKeyEpiglottisBase;
      key_t = self.app.markerKeyEpiglottisTip;
      delta = horizontalMirror * (self.markersTransformed.(key_t) ...
                                  - self.markersTransformed.(key_b));
      epiglotticAngle = atan2 (delta(2, :), delta(1, :));

      % Clockwise rotation is positive for Epiglottis angle (NOT mathematical).
      epglts_angle_from_initial = -(epiglotticAngle - epiglotticAngle(1)); 
      epglts_angle_from_initial_deg = epglts_angle_from_initial * 180/pi;
      
      subplot (3, 3, 7); 
      plot (tseq, epglts_angle_from_initial_deg, 'r', 'linewidth', 1.5); 
      grid on;
      ylabel ('angle[deg]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Epiglottic angle}');
      
      % Head of fluid
      subplot (3, 3, 8); 
      key = self.app.markerKeyFoodBolusHead;
      plot (tseq, self.markersTransformed.(key)(2, :), 'm', 'linewidth', 1.5); 
      grid on;
      ylabel ('displacement[mm]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Head of Bolus}');
      
      % UES opening 
      subplot (3, 3, 9);
      key1 = self.app.markerKeyUESAnterior;
      key2 = self.app.markerKeyUESPosterior;
      difference = self.markersTransformed.(key1) - self.markersTransformed.(key2);
      distance = sqrt (difference(1,:).^2 + difference(2,:).^2);
      plot (tseq, distance, 'linewidth', 1.5);
      grid on;
      ylabel ('displacement[mm]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{UES opening}');
      
      
      % % Hyoid excursion
      % subplot (3, 3, 1);
      % key = self.app.markerKeyHyoidAnterior;
      % plot (self.markersTransformed.(key)(1, :), ...
      %       self.markersTransformed.(key)(2, :), ...
      %       ':ob', ...
      %       'LineWidth', 1.0, ...
      %       'MarkerEdgeColor', 'k', ...
      %       'MarkerFaceColor', 'y', ...
      %       'MarkerSize', 5); 
      % grid on;

      % indexToLabel = [0:5:self.frameCount];
      % indexToLabel(1) = 1;
      % for i = 1 : size(indexToLabel, 2)
      %   label = sprintf('\\it\\bf{%d}', indexToLabel(i));
      %   text (self.markersTransformed.(key)(1, indexToLabel(i)), ...
      %         self.markersTransformed.(key)(2, indexToLabel(i)), ...
      %         label, ...
      %         'verticalalignment', 'bottom', ...
      %         'horizontalalignment', 'left', ...
      %         'color', 'r', ...
      %         'fontsize', 12);
      % end 

      % ylabel ('distance[mm]', 'fontsize', 10);
      % xlabel ('distance[mm]', 'fontsize', 10);
      % title ('\bf{Hyoid excursion}');

      % % Larynx posterior
      % subplot (3, 3, 8); 
      % key = self.app.markerKeyVocalFoldPosterior;
      % plot (tseq, self.markersTransformed.(key)(2, :), 'k', 'linewidth', 1.5); 
      % grid on;
      % ylabel ('distance[mm]', 'fontsize', 10);
      % xlabel ('time[sec]', 'fontsize', 10);
      % title ('\bf{Larynx-post. edge}');

      % % Epiglottis-Hyoid anterior
      % subplot (3, 3, 9); 
      % key = self.app.markerKeyHyoidAnterior;
      % plot (self.markersTransformed.(key)(1, :), ...
      %       epiglotticAngleDeg, ...
      %       ':ok', 'LineWidth', 1.0, ...
      %       'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'c', ...
      %       'MarkerSize', 5); 
      % grid on;
      % ylabel ('epiglottic angle', 'fontsize', 10);
      % xlabel ('hyoid horizontal', 'fontsize', 10);
      % title ('\bf{Epiglottis-Hyoid(ant.)}');

      
      % Create another window for velocity plots.
      subWindowPosition = mainWindowPosition + [10 -10 0 0];
      subWindowName = sprintf('Velocities of %s', self.movieFileName);
      
      subPlotWindow = figure ( ...
        'NumberTitle', 'off', ...
        'Position', subWindowPosition, ...
        'Name', subWindowName ...
        );
      
      dt = 1./self.frameRate;
      
      % Hyoid vertical movement
      subplot (3, 3, 1);
      key = self.app.markerKeyHyoidAnterior;
      plot (tseq, ...
            self.approximateVelocity (self.markersTransformed.(key)(2, :), dt), ...
            'b', 'linewidth', 1.5); 
      grid on;
      ylabel ('velocity[mm/s]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Hyoid: vertical velocity}');
      
      % Hyoid horizontal movement
      key = self.app.markerKeyHyoidAnterior;
      subplot (3, 3, 4); % Just below the subplot above.
      plot (tseq, ...
            self.approximateVelocity (self.markersTransformed.(key)(1, :), dt), ...
            'b', 'linewidth', 1.5); 
      grid on;
      ylabel ('velocity[mm/s]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Hyoid: horizontal velocity}');
      
      % Larynx vertical movement
      subplot (3, 3, 2); 
      key = self.app.markerKeyVocalFoldAnterior;
      plot (tseq, ...
            self.approximateVelocity (self.markersTransformed.(key)(2, :), dt), ...
            'k', 'linewidth', 1.5); 
      grid on;
      ylabel ('velocity[mm/s]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Larynx: vertical velocity}');
      
      % Larynx horizontal movement
      subplot (3, 3, 5); 
      key = self.app.markerKeyVocalFoldAnterior;
      plot (tseq, ...
            self.approximateVelocity (self.markersTransformed.(key)(1, :), dt), ... 
            'k', 'linewidth', 1.5); 
      grid on;
      ylabel ('velocity[mm/s]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Larynx: horizontal velocity}');
      
      % Arytenoid vertical movement
      subplot (3, 3, 3); 
      key = self.app.markerKeyArytenoid;
      plot (tseq, ...
            self.approximateVelocity (self.markersTransformed.(key)(2, :), dt), ...
            'k', 'linewidth', 1.5); 
      grid on;
      ylabel ('velocity[mm/s]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Arytenoid: vertical velocity}');
      
      % Arytenoid horizontal movement
      subplot (3, 3, 6); 
      key = self.app.markerKeyArytenoid;
      plot (tseq, ...
            self.approximateVelocity (self.markersTransformed.(key)(1, :), dt), ...
            'k', 'linewidth', 1.5); 
      grid on;
      ylabel ('velocity[mm/s]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Arytenoid: horizontal velocity}');
      
      % Epiglottic angle
      subplot (3, 3, 7); 
      plot (tseq, ...
            self.approximateVelocity (epglts_angle_from_initial_deg, dt), ...
            'r', 'linewidth', 1.5); 
      grid on;
      ylabel ('angular velocity[deg/s]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Epiglottic angular velocity}');
      
      % Head of Bolus
      subplot (3, 3, 8); 
      key = self.app.markerKeyFoodBolusHead;
      bolusHorizontalVelocity = ...
        self.approximateVelocity (self.markersTransformed.(key)(1, :), dt);
      bolusVerticalVelocity = ...
        self.approximateVelocity (self.markersTransformed.(key)(2, :), dt);
      bolusVelocity = sqrt (bolusHorizontalVelocity.^2 + ...
                            bolusVerticalVelocity.^2);
      plot (tseq, bolusVelocity, ...
            'm', 'linewidth', 1.5); 
      grid on;
      ylabel ('velocity[mm/s]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{Head of Bolus}');
      
      % UES opening 
      subplot (3, 3, 9);
      plot (tseq, ...
            self.approximateVelocity (distance, dt), ...
            'linewidth', 1.5);
      grid on;
      ylabel ('velocity[mm/s]', 'fontsize', 10);
      xlabel ('time[sec]', 'fontsize', 10);
      title ('\bf{UES opening velocity}');
      
    end

    
    
    
    % --------------------------------------------------------------------------
    % 
    %  Method: transformMarkers
    %
    %  This function transforms the trajectories of markers using C2-C4.
    %  Note that y-axis is from C4 to C2, and x-axis is obtained by
    %  rotating the y-axis by 90 degrees counter clockwise.
    %  (NOT a mathematical convention!!!)
    %
    % --------------------------------------------------------------------------
    function transformMarkers (self, plotData)
      % Examine coin markers and estimate the diameter of the coin by averaging.
      coinLengths = [];
      for i = 1 : (self.frameCount)
        coinAnterior = plotData.(self.app.markerKeyCoinAnterior)(:, i);
        coinPosterior = plotData.(self.app.markerKeyCoinPosterior)(:, i);

        if norm(coinAnterior) ~= 0 && norm(coinPosterior) ~= 0  
          coinLength = norm (coinPosterior - coinAnterior);
          coinLengths = [coinLengths coinLength];
        end 
      end 
      coinLengthInAverage = mean (coinLengths);
      
      if coinLengthInAverage < 5
        mode = struct('WindowStyle', 'modal', 'Interpreter', 'tex');
        errordlg({'{\bf Coin is too small.}', ...
                  '     (Shorter than 5 pixels.)'}, ...
                 'Coin Picking Error', mode);
        return;
      end 

      scaleFactor = self.app.pref_diameterCoin / coinLengthInAverage; 

      % Create a struct to save markers transformed.
      self.markersTransformed = struct;

      % Copy time sequence.
      self.markersTransformed.('time') = self.markers.('time');

      for i = 1:size(self.app.markerDefaults, 1) % Add fields according to
                                                 % the markerDefaults member
                                                 % of the app.
        self.markersTransformed.(self.app.markerDefaults{i, 7}) ...
          = zeros (2, self.frameCount);  % Time series of 2 dimensional vector.
      end

      %
      % Process each frame
      % ------------------------------------------------------------------------
      for i = 1 : self.frameCount

        C2_inverted = plotData.(self.app.markerKeyC2)(:, i);
        C4_inverted = plotData.(self.app.markerKeyC4)(:, i);

        % Invert vertical axis (v).
        imageHeight = self.videoObject.Height;

        C2 = C2_inverted;
        C2(2) = imageHeight - C2_inverted(2);

        C4 = C4_inverted;
        C4(2) = imageHeight - C4_inverted(2);

        R = eye(2);
        p = zeros(2, 1);

        if norm(C2) ~= 0 && norm(C4) ~= 0
          % Setup x-y coordinate system.
          % The head and tail of y-axis are C2 and C4 markers, respectively.
          % The x-axis is obtained by rotating the y-axis by 90 degrees clockwise.

          if norm(C2 - C4) < 5
            mode = struct('WindowStyle', 'modal', 'Interpreter', 'tex');
            description = ... 
              sprintf('     (Less than 5 pixels apart at frame %d.)', i);
            errordlg({'{\bf Markers for C2 and C4 are too close.}', ...
                      description}, ...
                     'Markers Too Close Error', mode);
            return;
          end

          y_hat = (C2 - C4)/norm(C2 - C4);
          angle = -pi/2;
          x_hat = [cos(angle) -sin(angle); sin(angle) cos(angle)]*y_hat;
          R = [x_hat y_hat];
          p = C4;
        end % of if

        % Convert (u, v) to (x, y).

        for j = 1 : size(self.app.markerDefaults, 1)

          % Extract uv coordinate of each marker.
          markerKey = self.app.markerDefaults{j, 7};
          marker = plotData.(markerKey)(:, i);

          % Invert v coordinate so that the lower left corner should be (0, 0).
          markerInverted = marker;
          markerInverted(2) = imageHeight - marker(2);

          % Transform the coordinate, and 
          % negate the x-coordinates because left-handed coordinate system
          % is used for x-y coordinate system.
          self.markersTransformed.(markerKey)(:, i) = ...
            scaleFactor * [-1 0; 0 1] * (R' * markerInverted - R'*p);

        end % of for j

      end % of for i
      
    end
    


    
    % --------------------------------------------------------------------------
    % 
    %  Method: createAnimationWindow 
    %
    %  This function creates an animation window to show the movement
    %  of markers selected.
    %
    % --------------------------------------------------------------------------
    function createAnimationWindow (self, src, event)
      
      % Create a window
      window = figure ( ...
        'NumberTitle', 'off', ...
        'Name', 'Movement of Markers Selected', ...
        'Position', self.window.Position);

      % Move the window to the center of the screen.
      movegui (window, 'center');

      % Make the window current figure.
      figure (window);
      
      % Create axes and clear.
      scale = .92;
      thePosition = self.imageView.Position + [20 10 0 0];
      thePosition(3) = thePosition(3) * scale;
      thePosition(4) = thePosition(4) * scale;
      self.animationView = axes ('Units', 'pixels', ...
                      'Box', 'on', ...
                      'XTick', [], 'YTick', [], ...
                      'XLim', [0 self.imageView.Position(3)], ...
                      'YLim', [0 self.imageView.Position(4)], ...
                      'xdir', 'reverse', ...
                      'Position', thePosition);

      cla (self.animationView);
      
      
      % Place instruction and checkboxes to choose markers to animate.
      % ------------------------------------------------------------------------
      mgn = 20;
      controlHOffset = 4*mgn + self.animationView.Position(3);
      controlV = self.animationView.Position(4);
      controlWidth = self.markerTable.Extent(3);
      
      markersCount = size (self.app.markerDefaults, 1);
      
      % Place checkboxes
      markerStrings = {markersCount, 1};
      self.markersToAnimateCheckbox = struct;
      
      uicontrol (window, ...
          'Style', 'text', ...
          'FontWeight', 'bold', ...
          'HorizontalAlignment', 'left', ...
          'String', 'Choose markers to animate:', ...
          'Position', [controlHOffset, controlV, ...
                       controlWidth, 20]);
      
      for i = 3 : markersCount-2  % Exclude coin markers, C2, and C4.
        markerKey = self.app.markerDefaults{i, 7};
        
        markerStrings(i - 2) = strcat('<html><font color="#', ...
          self.app.markerDefaults(i,3), ...
          self.app.markerDefaults(i,4), ...
          self.app.markerDefaults(i,5), '">', ...
          self.app.markerDefaults(i,2), '</font></html>');

        controlV = controlV - 20;
        checkboxHandle = uicontrol (window, ...
            'Style', 'checkbox', ...
            'Value', 0, ...
            'String', markerStrings{i - 2}, ...
            'Position', [controlHOffset, controlV, controlWidth, 12]);

        self.markersToAnimateCheckbox.(markerKey) = checkboxHandle;
      end
      
      % Place redraw pushbutton.
      redrawButton = ...
          uicontrol (window, ...
                     'Style', 'pushbutton', ...
                     'String', 'Redraw', ...
                     'Position', [controlHOffset, mgn, controlWidth, 24], ...
                     'Callback', {@(src, event)animateMovement(self, src, event)});
    end
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: animateMovement
    %
    %  This function animates trajectories of the markers selected.
    %
    % --------------------------------------------------------------------------
    function animateMovement (self, src, event)
      % Save current markers to model object.
      saveCurrentFrameMarkersToModel (self);

      % Choose raw or smoothed trajectory to plot.
      plotData = self.prepareTrajectoriesToProcess ();

      % Coordinate transformation of markers.
      self.transformMarkers (plotData);

      % Make the animationView as active axes.
      cla (self.animationView);

      
      % Extract trajectories of the markers selected.
      markersToDraw = [];
      
      markersCount = size (self.app.markerDefaults, 1);
      
      for i = 3 : markersCount-2  % Exclude coin markers, C2, and C4.
        markerKey = self.app.markerDefaults{i, 7};
        
        if self.markersToAnimateCheckbox.(markerKey).Value == 1 % The marker is selected.
          markersToDraw = [markersToDraw, self.markersTransformed.(markerKey)];
        end
        
      end
      
      % Set the range of axis.
      min_axis = min (markersToDraw, [] ,2);
      max_axis = max (markersToDraw, [], 2);
      
      aspectRatioMarkerRange = (max_axis(1) - min_axis(1)) / (max_axis(2) - min_axis(2));
      aspectRatioImageView = (self.imageView.XLim(2) - self.imageView.XLim(1)) ...
          / (self.imageView.YLim(2) - self.imageView.YLim(1));
      
      if aspectRatioMarkerRange > aspectRatioImageView % Wider range of movement
        x_lim = [min_axis(1)-10, max_axis(1)+10];
        len = (x_lim(2) - x_lim(1)) / aspectRatioMarkerRange;
        y_lim = [min_axis(2) - .5*abs((max_axis(2) - min_axis(2))-len), ...
                 max_axis(2) + .5*abs((max_axis(2) - min_axis(2))-len)];
        
      else % Taller range of movement
        y_lim = [min_axis(2)-5, max_axis(2)+5];
        len = (y_lim(2) - y_lim(1)) * aspectRatioMarkerRange;
        x_lim = [min_axis(1) - .5*abs((max_axis(1) - min_axis(1))-len), ...
                 max_axis(1) + .5*abs((max_axis(1) - min_axis(1))-len)];
        
      end
     
      axis([x_lim, y_lim]); 
      axis equal;
                  
      for i = 1 : size(self.markers.('time'), 2)
        % Mandible anterior & posterior
        key_a = self.app.markerKeyMandibleAnterior;
        key_p = self.app.markerKeyMandiblePosterior;
        index = 3;
        
        self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);
                
        % Hyoid anterior & posterior
        key_a = self.app.markerKeyHyoidAnterior;
        key_p = self.app.markerKeyHyoidPosterior;
        index = 5;
        
        self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);
        
        % Epiglottis 
        key_a = self.app.markerKeyEpiglottisTip;
        key_p = self.app.markerKeyEpiglottisBase;
        index = 7;
        
        self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);
        
        % Larynx 
        key_a = self.app.markerKeyVocalFoldAnterior;
        key_p = self.app.markerKeyVocalFoldPosterior;
        index = 9;
        
        self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);
        
        % Bolus (No anterior/posterior pair)
        key_a = self.app.markerKeyFoodBolusHead;
        key_p = self.app.markerKeyFoodBolusHead;
        index = 11;
        
        self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);
        
        % Arytenoid (No anterior/posterior pair)
        key_a = self.app.markerKeyArytenoid;
        key_p = self.app.markerKeyArytenoid;
        index = 12;
        
        self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);
        
        % Maxilla
        key_a = self.app.markerKeyMaxillaAnterior;
        key_p = self.app.markerKeyMaxillaPosterior;
        index = 13;
        
        self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);
        
        % UES
        key_a = self.app.markerKeyUESAnterior;
        key_p = self.app.markerKeyUESPosterior;
        index = 15;
        
        self.drawAnteriorPosterior (key_a, key_p, index, i, x_lim, y_lim);
        
        
        pause (1./self.frameRate);
      end

      grid on;
      hold off;

    end
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: drawAnteriorPosterior
    %
    %  This function draws anterior/posterior markers and connect them.
    %  If only on is turned on, this function does not draw an edge.
    %
    % --------------------------------------------------------------------------
    function drawAnteriorPosterior (self, key_a, key_p, index, i, x_lim, y_lim)
      markerColorCode = [num2str(self.app.markerDefaults {index, 3}), ... 
                         ' ', ...
                         num2str(self.app.markerDefaults {index, 4}), ...
                         ' ', ...
                         num2str(self.app.markerDefaults {index, 5})];
      markerColor = (sscanf (markerColorCode, '%x').')/256;

      if self.markersToAnimateCheckbox.(key_a).Value == 1 % Anterior is on.
        if self.markersToAnimateCheckbox.(key_p).Value == 1 % Posterior is also on.
          plot ([self.markersTransformed.(key_a)(1, i), self.markersTransformed.(key_p)(1, i)], ...
                [self.markersTransformed.(key_a)(2, i), self.markersTransformed.(key_p)(2, i)], ...
                '--o', 'LineWidth', 1.0, ...
                'MarkerEdgeColor', 'k', ...
                'MarkerFaceColor', markerColor, ...
                'Color', markerColor, ...
                'MarkerSize', 5);
          axis ([x_lim, y_lim]);
          set (gca, 'xdir', 'reverse');
          axis equal;
          hold on;
          
        else % Posterior is off.
          plot (self.markersTransformed.(key_a)(1, i), self.markersTransformed.(key_a)(2, i), ...
                '--o', 'LineWidth', 1.0, ...
                'MarkerEdgeColor', 'k', ...
                'MarkerFaceColor', markerColor, ...
                'Color', markerColor, ...
                'MarkerSize', 5);
          axis ([x_lim, y_lim]);
          set (gca, 'xdir', 'reverse');
          axis equal;
          hold on;
          
        end 
        
      else % Anterior if off.
        if self.markersToAnimateCheckbox.(key_p).Value == 1 % Posterior is on.
          plot (self.markersTransformed.(key_p)(1, i), self.markersTransformed.(key_p)(2, i), ...
                '--o', 'LineWidth', 1.0, ...
                'MarkerEdgeColor', 'k', ...
                'MarkerFaceColor', markerColor, ...
                'Color', markerColor, ...
                'MarkerSize', 5);
          axis ([x_lim, y_lim]);
          set (gca, 'xdir', 'reverse');
          axis equal;
          hold on;
        end
      end
      
      % Mark anterior point with a label, if it is enabled.
      if self.markersToAnimateCheckbox.(key_a).Value == 1
        if mod (i, 10) == 0 || i == 1
          label = sprintf('\\it\\bf{%d}', i);
          text (self.markersTransformed.(key_a)(1, i), self.markersTransformed.(key_a)(2, i), ...
                label, ...
                'verticalalignment', 'bottom', ...
                'horizontalalignment', 'left', ...
                'color', 'r', ...
                'fontsize', 12);
        end
      end
      
      % Mark posterior point with a label, if it is enabled.
      if ~strcmp(key_a, key_p) && self.markersToAnimateCheckbox.(key_p).Value == 1
        if mod (i, 10) == 0 || i == 1
          label = sprintf('\\it\\bf{%d}', i);
          text (self.markersTransformed.(key_p)(1, i), self.markersTransformed.(key_p)(2, i), ...
                label, ...
                'verticalalignment', 'bottom', ...
                'horizontalalignment', 'left', ...
                'color', 'r', ...
                'fontsize', 12);
        end
      end
      
    end
      

    
    
    % --------------------------------------------------------------------------
    %
    %  Method: plotSuperimposing
    %
    %  This callback function creates superimposing plot.
    %
    % --------------------------------------------------------------------------
    function plotSuperimposing (self, src, event)
      % Save current markers to model object.
      saveCurrentFrameMarkersToModel (self);

      % Choose raw or smoothed trajectory to plot.
      plotData = self.prepareTrajectoriesToProcess ();

      % Coordinate transformation of markers.
      self.transformMarkers (plotData);
      
      % Create a window.
      scsize = get(0, 'screensize');
      plotPosition = [0.2*scsize(4) 0.07*scsize(4) 0.8*scsize(4) 0.8*scsize(4)];
      superimposingPlotWindow = figure ( ...
        'NumberTitle', 'off', ...
        'Position', plotPosition.*[0.8 7 1.0 0.8], ...
        'Name', 'Superimposing' ...
        );

      
      tseq = plotData.('time');
      
      % Hyoid-vertical displacement
      key = self.app.markerKeyHyoidAnterior;
      l1 = line (tseq, self.markersTransformed.(key)(2, :)); 
      set (l1, 'color', 'b', 'linewidth', 1.5);

      % Food bolus head
      key = self.app.markerKeyFoodBolusHead;
      l2 = line (tseq, self.markersTransformed.(key)(2, :));
      set (l2, 'color', 'm', 'linestyle', '--', 'linewidth', 1.5);

      % Vocal fold anterior vertical displacement
      key = self.app.markerKeyVocalFoldAnterior;
      l3 = line (tseq, self.markersTransformed.(key)(2, :));
      set (l3, 'color', 'k', 'linestyle', '-.', 'linewidth', 1.5);

      % Epiglottic angle
      horizontalMirror = [-1 0; 0 1];
      key_b = self.app.markerKeyEpiglottisBase;
      key_t = self.app.markerKeyEpiglottisTip;
      delta = horizontalMirror * (self.markersTransformed.(key_t) ...
                                  - self.markersTransformed.(key_b));
      epiglotticAngle = atan2 (delta(2, :), delta(1, :));
      epiglotticAngle = -(epiglotticAngle - epiglotticAngle(1)); % Clockwise 
                                                                 % rotation is
                                                                 % positive.
      epiglotticAngleDeg = epiglotticAngle * 180 / pi;
      
      l4 = line (tseq, epiglotticAngleDeg);
      set (l4, 'color', 'r', 'linewidth', 2, 'lineStyle', '-');

      % Arytenoid
      key = self.app.markerKeyArytenoid;
      l5 = line (tseq, self.markersTransformed.(key)(2, :));
      set (l5, 'color', 'k', 'linewidth', 2,  'lineStyle', ':');

      legend ([l1; l2; l3; l4; l5], ...
              char('hyoid (mm)', ...
                   'fluid (mm)', ...
                   'larynx (mm)', ...
                   'epiglottic angle (deg)', ...
                   'arytenoid (mm)'), 4);

      xlabel ('\bf{time[sec]}', 'fontsize', 11);
      ylabel ('\bf{vertical displacement[mm]}', 'fontsize', 11);
      title ('\bf{Superimposing}', 'fontsize', 11);
      ylim ('auto');
      xlim ('auto');

      grid on;

    end
    
    
    
      
    % --------------------------------------------------------------------------
    %
    %  Method: scrollImage 
    %
    %  This function scrolls the image.
    %
    % --------------------------------------------------------------------------
    function scrollImage (self, src, event)
      disp('scroll: not implemented yet.')
    end




    % --------------------------------------------------------------------------
    %
    %  Method: saveCurrentFrameMarkersToModel
    %
    %  This function saves current markers to markers array.
    %
    % --------------------------------------------------------------------------
    function saveCurrentFrameMarkersToModel (self)
      % Store time.
      idx = self.currentFrameIndex;
      % currentTime = (idx - 1)/self.frameRate;
      % self.markers.time(idx) = currentTime;

      % Copy marker data from table view to model object.
      for i = 1:size(self.app.markerDefaults, 1)
        self.markers.(self.app.markerDefaults{i, 7})(1, idx) = ...
          self.markerTable.Data {i, 4};
        self.markers.(self.app.markerDefaults{i, 7})(2, idx) = ...
          self.markerTable.Data {i, 5};
      end 

      correctFrameIndicesWithCoinMarkers (self);
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: correctFrameIndicesWithCoinMarkers
    %
    %  This function examines current frame markers and corrects 
    %  frameIndicesWithCoinMarkers array accordingly.
    %
    % --------------------------------------------------------------------------
    function correctFrameIndicesWithCoinMarkers (self)
      % Determine whether current frame index is already found.
      indices = find (...
        self.frameIndicesWithCoinMarkers == self.currentFrameIndex);

      % Check whether this frame has coin markers or not.
      coin_anterior_key = self.app.markerKeyCoinAnterior;
      coin_posterior_key = self.app.markerKeyCoinPosterior;
      current = self.currentFrameIndex;
      if self.markers.(coin_anterior_key)(1, current) ~= 0 && ... % anterior
         self.markers.(coin_anterior_key)(2, current) ~= 0 && ...
         self.markers.(coin_posterior_key)(1, current) ~= 0 && ... % posterior
         self.markers.(coin_posterior_key)(2, current) ~= 0
        % Anterior and posterior coin markers exist in this frame.

        if size (indices, 2) == 0 % Current frame is a new frame with coin 
                                  % markers.
          self.frameIndicesWithCoinMarkers = ...
            [self.frameIndicesWithCoinMarkers self.currentFrameIndex];

        end 

      else % Current frame does not have coin markers.
        self.frameIndicesWithCoinMarkers (indices) = [];

      end 

      % disp (self.frameIndicesWithCoinMarkers)
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: loadAndDisplayImage
    %
    %  This function loads a frame which corresponds to currentFrameIndex.
    %  Then displays it on imageView axes with markers if there are any.
    %
    % --------------------------------------------------------------------------
    function loadAndDisplayImage (self)
      % Load image.
      loadFrame (self, self.currentFrameIndex);
      axes (self.imageView);
      frameData = self.movieData(self.currentFrameIndex).cdata;

      if self.clearViewCheckbox.Value == 1
        M = max(frameData(:));
        m = min(frameData(:));
        for i = 1:self.videoObject.Height 
          for j = 1:self.videoObject.Width 

            % 1. Linear function
            % frameData (i,j) = 255/(M-m)*(frameData(i,j) - m);

            % 2. Sigmoid function
            k = 7;
            x0 = double(M + m)/2/255;
            x = double(frameData(i,j))/255;
            frameData (i,j) = uint8(1/(1+exp(-k*(x - x0))) * 255);
          end
        end
      end
      imgHandle = imshow (frameData);
      %imgHandle = imagesc (self.movieData(self.currentFrameIndex).cdata);
      axis image;
      set (self.imageView, 'XTick', [], 'YTick', []);
     
      % Set callback function for mouse button down event.
      set (self.imageView, ...
        'ButtonDownFcn', {@(src, event)mouseClicked(self, src, event)});
      set (imgHandle, 'HitTest', 'off');
   
    end
   



    % --------------------------------------------------------------------------
    %
    %  Method: loadCurrentMarkersFromModel
    %
    %  This function loads marker data from 'marker' array to the data of 
    %  current marker table.
    %
    % --------------------------------------------------------------------------
    function loadCurrentMarkersFromModel (self)
      % Load marker data from model object to table view.
      current = self.currentFrameIndex;
      for i = 1 : size(self.app.markerDefaults, 1)
        self.markerTable.Data {i, 4} = ...
          self.markers.(self.app.markerDefaults{i, 7})(1, current);
        self.markerTable.Data {i, 5} = ...
          self.markers.(self.app.markerDefaults{i, 7})(2, current);
      end 

      % Check whether current frame is registered to the indices of the frames 
      % with coin markers.
      indices = find (self.frameIndicesWithCoinMarkers == current);

      % Current frame contains coin markers.
      if size (indices, 2) > 0
        self.markerTable.Data (1, 2) = num2cell(true);
        self.markerTable.Data (2, 2) = num2cell(true);

      else 
        % Number of frames with coin markers are smaller than threshold.
        if size (self.frameIndicesWithCoinMarkers, 2) < ... 
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
    
   

    
    % --------------------------------------------------------------------------
    %
    %  Method: loadFrame
    %
    %  This function loads a frame which corresponds to the frame counter given.
    %  If the frame was already loaded, this function does nothing.
    %  Otherwise, it loads the frame from video object.
    %
    % --------------------------------------------------------------------------
    function loadFrame (self, counter)
      self.videoObject.CurrentTime = (counter - 1)/self.frameRate;
      
      % Load the frame which has never been loaded before
      if size(self.movieData, 2) < counter || ... 
          size(self.movieData(counter).cdata, 1) == 0 || ...
          self.movieData(counter).loaded == 0
        
        h = waitbar (0, 'Reading video frame ...');
        
        while self.videoObject.CurrentTime <= counter/self.frameRate
          self.movieData(counter).cdata = rgb2gray(readFrame(self.videoObject));
          self.movieData(counter).colormap = gray;
        end
        
        self.movieData(counter).loaded = 1;
        waitbar (1);
        close (h);
      end
    end
    
    
    
   
    % --------------------------------------------------------------------------
    %
    %  Method: activateRow
    %
    %  This function activates the row with the index given.
    %  The active row is where the position of the next mouse click will be 
    %  written.
    %
    % --------------------------------------------------------------------------
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




    % --------------------------------------------------------------------------
    %
    %  Method: processKeyDown
    %
    %  This function is called when a key press event happens in movie window.
    %
    % --------------------------------------------------------------------------
    function processKeyDown (self, src, event)
      % left & right arrows, left & right brackets
      if strcmp (event.Key, 'rightarrow') || strcmp (event.Key, 'leftarrow') ...
        || strcmp (event.Key, 'rightbracket') || strcmp (event.Key, 'leftbracket')

        % Distinguish keys.
        if strcmp (event.Key, 'rightarrow')
          counter = self.currentFrameIndex + 1;
        elseif strcmp (event.Key, 'leftarrow')
          counter = self.currentFrameIndex - 1;
        elseif strcmp (event.Key, 'rightbracket')
          counter = self.currentFrameIndex + self.frameRate;
        elseif strcmp (event.Key, 'leftbracket')
          counter = self.currentFrameIndex - self.frameRate;
        end

        % Calculate new frame counter by saturating if needed.
        newFrameCounter = self.saturateFrameCounter (counter);

        % Shift frame.
        self.shiftFrameTo (newFrameCounter);

        % Change the value of the slider
        set (self.timeSlider, 'Value', newFrameCounter);

      % backspace
      elseif strcmp (event.Key, 'backspace') || strcmp (event.Key, 'delete')

        self.deleteSelectedMarker ();

      end
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: shiftFrameTo
    %
    %  This function changes current frame.
    %
    % --------------------------------------------------------------------------
    function shiftFrameTo (self, newFrameCounter)
      % Save current frame markers
      saveCurrentFrameMarkersToModel (self);

      % Backup current frame counter.
      previousFrameCounter = self.currentFrameIndex;

      self.setFrameCounterValue (newFrameCounter);
      self.currentFrameIndex = newFrameCounter;

      % Copy markers from the previous frame to new one.
      copyMarkersToCurrentFrame (self, previousFrameCounter);

      % Load image if needed and display
      loadFrameImageWithMarkers (self);

    end




    % --------------------------------------------------------------------------
    %
    %  Method: frameHasActualMarkersPicked
    %
    %  This function examines whether actual markers are picked or not in
    %  a frame.
    %
    % --------------------------------------------------------------------------
    function actualMarkersPicked = frameHasActualMarkersPicked (self, index)
      countMarkers = size (self.app.markerDefaults, 1);
      actualMarkersPicked = 0;
      for i = 1:countMarkers
        if norm (self.markers.(self.app.markerDefaults{i, 7})(:, index)) ~= 0
          actualMarkersPicked = 1;
          break;
        end 
      end 
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: copyMarkersToCurrentFrame
    %
    %  This function copies markers to current frame if required.
    %
    % --------------------------------------------------------------------------
    function copyMarkersToCurrentFrame (self, prevIndex)
      % Copy previous markers when 
      %  1. the checkbox is checked, and 
      %  2. all the markers in the new frame are set to 0.
      countMarkers = size (self.app.markerDefaults, 1);
      current = self.currentFrameIndex;
      markersNotPickedInCurrentFrame = 1;
      for i = 1:countMarkers
        if norm (self.markers.(self.app.markerDefaults{i, 7})(:, current)) ~= 0
          markersNotPickedInCurrentFrame = 0;
          break;
        end
      end


      if self.copyMarkersCheckbox.Value == 1 && markersNotPickedInCurrentFrame 
        % This frame does not have any markers picked
        % and the copy markers checkbox is on.

        % Copy the marker data to table view data and model object.
        for i = 1 : countMarkers
          marker_key = self.app.markerDefaults{i, 7};
          self.markerTable.Data {i, 4} = ...
            self.markers.(marker_key)(1, prevIndex);

          self.markers.(marker_key)(1, current) = ...
            self.markers.(marker_key)(1, prevIndex);

          self.markerTable.Data {i, 5} = ...
            self.markers.(marker_key)(2, prevIndex);

          self.markers.(marker_key)(2, current) = ...
            self.markers.(marker_key)(2, prevIndex);

          % Mark that the raw trajectory of the marker is editted.
          % (Re-smoothing required later.)
          if self.smoothingParameters.(marker_key)(1) > 0
            self.smoothingParameters.(marker_key)(1) = ...
              -1 * self.smoothingParameters.(marker_key)(1);
          end

        end 
        
        % If enough number of coin markers are selected,
        % we don't have to copy the coin markers to this new frame.
        if size (self.frameIndicesWithCoinMarkers, 2) >= ...
              self.app.pref_coinMarkerSelectionCount 

          % Zero coin anterior marker.
          self.markerTable.Data (1, 2) = num2cell (false);
          self.markerTable.Data {1, 4} = 0;
          self.markerTable.Data {1, 5} = 0;
          
          % Zero coin posterior marker.
          self.markerTable.Data (2, 2) = num2cell (false);
          self.markerTable.Data {2, 4} = 0;
          self.markerTable.Data {2, 5} = 0;

          % Zero model object.
          self.markers.(self.app.markerKeyCoinAnterior)(:, current) = [0; 0];
          self.markers.(self.app.markerKeyCoinPosterior)(:, current) = [0; 0];
        end 

        if frameHasActualMarkersPicked (self, current) % Actual markers copied.
          markUnsavedChanges (self);
        end

        % Save the data from the table view to model object.
        % saveCurrentFrameMarkersToModel (self);

      else % No copy for this frame.
        % loadCurrentMarkersFromModel (self);

      end 
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: markUnsavedChanges
    %
    %  This function sets unsavedChanges flag and modify GUI accordingly.
    %
    % --------------------------------------------------------------------------
    function markUnsavedChanges (self)
      % Mark there is unsaved change.
      self.hasUnsavedChanges = 1;

      % Change the title of the window to represent that the file is changes.
      windowTitle = sprintf('%s --- Edited', self.movieFileName);
      self.window.Name = windowTitle;
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: clearUnsavedChanges
    %
    %  This function clears unsavedChanges flag and modify GUI accordingly.
    %
    % --------------------------------------------------------------------------
    function clearUnsavedChanges (self)
      % Mark there is unsaved change.
      self.hasUnsavedChanges = 0;

      % Change the title of the window.
      self.window.Name = self.movieFileName;
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: deleteSelectedMarker
    %
    %  This function deletes the data from active marker.
    %
    % --------------------------------------------------------------------------
    function deleteSelectedMarker (self)
      if self.selectedMarkerIndex > 0
        % Update markers.
        self.writeMarkerToRow (self.selectedMarkerIndex, 0, 0);
        self.updateMarkerDrawn (self.selectedMarkerIndex, 0, 0);

        % Reset active marker index.
        self.selectedMarkerIndex = 0;

        set (self.window, 'WindowButtonMotionFcn', '');
        % set (self.window, 'WindowButtonDownFcn', '');
      

        self.markUnsavedChanges ();
      end 
    end




    % --------------------------------------------------------------------------
    %
    %  Method: loadFrameImageWithMarkers
    %
    %  This function loads frame image and its associated markers which 
    %  correspond to current frame index.
    %
    % --------------------------------------------------------------------------
    function loadFrameImageWithMarkers (self)
      self.loadAndDisplayImage ();
      self.loadCurrentMarkersFromModel ();
      
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

      self.drawEdges ();
      self.drawMarkers ();
    end




    % --------------------------------------------------------------------------
    %
    %  Method: saturateFrameCounter
    %
    %  This function limits the frame counter so that it is always between 
    %  1 and the maximum number of frames.
    %
    % --------------------------------------------------------------------------
    function counterSaturated = saturateFrameCounter (self, counter)
      if counter < 1
        counterSaturated = 1;
      elseif counter >= self.frameCount 
        counterSaturated = self.frameCount;
      else 
        counterSaturated = counter;
      end
    end




    % --------------------------------------------------------------------------
    %
    %  Method: timeSliderClicked
    %
    %  This function is called when the slider is clicked.
    %
    % --------------------------------------------------------------------------
    function timeSliderClicked (self, src, event)
      newFrameCounter = round (src.Value);
      self.shiftFrameTo (newFrameCounter);
    end
   

    
    
    % --------------------------------------------------------------------------
    %
    %  Method: setFrameCounterValue
    %
    %  This function displays current frame counter in the text edit field 
    %  below the slider.
    %
    % --------------------------------------------------------------------------
    function setFrameCounterValue (self, val)
      set (self.currentFrameField, 'String', num2str(val));
    end
    
    
    
   
    % --------------------------------------------------------------------------
    %
    %  Method: frameCounterEdited
    %
    %  This callback function is called when the frame counter display 
    %  is edited.
    %
    % --------------------------------------------------------------------------
    function frameCounterEdited (self, src, event)
      val = round(str2double(src.String));
      
      % Check minimum (which is 1, of course.)
      if (val < 1)
        set (src, 'String', '1');
        newFrameCounter = 1;
      elseif (val > self.frameCount) % Check maximum (which is the frameCount)
        set (src, 'String', num2str(self.frameCount));
        newFrameCounter = self.frameCount;
      else
        set (src, 'String', num2str(val));
        newFrameCounter = val;
      end

      % Shift frame.
      self.shiftFrameTo (newFrameCounter);
       
      % Change the value of the slider
      set (self.timeSlider, 'Value', newFrameCounter);
    end
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: isMovieLoaded
    %
    %  This function returns whether a movie file is loaded or not.
    %
    % --------------------------------------------------------------------------
    function movieLoaded = isMovieLoaded (self)
      if size(self.movieData, 2) > 0
        movieLoaded = 1;
      else 
        movieLoaded = 0;
      end
    end
    
    
    
    
    % --------------------------------------------------------------------------
    %
    %  Method: mouseClicked 
    %
    %  This callback function is called when a mouse button is clicked in the
    %  image display axes.
    %
    % --------------------------------------------------------------------------
    function mouseClicked (self, src, event)
      if strcmp (self.window.SelectionType, 'normal')
        % Get the position (x and y) of the mouse pointer.
        pos = get(self.imageView, 'CurrentPoint');
        x = round (pos(1, 1));
        y = round (pos(1, 2));

        index = 0;
        if self.selectedMarkerIndex == 0 % There is no marker selected.
          index = self.activeRowIndex;

        else % There is an marker selected. Modify it.
          index = self.selectedMarkerIndex;

        end 

        if index ~= 0
          self.writeMarkerToRow (index, x, y);
          self.activateNextEnabledRow ();

          % Draw markers 
          self.updateMarkerDrawn (index, x, y);

          self.markUnsavedChanges ();
        end 
      end
    end
   

    
 
    % --------------------------------------------------------------------------
    %
    %  Method: drawMarkers
    %
    %  This function draws markers in accordance to the color format.
    %
    % --------------------------------------------------------------------------
    function drawMarkers (self)
      self.markersDrawn = [];
      for i = 1 : size (self.app.markerDefaults, 1)
        % Extract color settings for the marker.
        markerColorCode = [num2str(self.app.markerDefaults {i, 3}), ... 
                           ' ', ...
                           num2str(self.app.markerDefaults {i, 4}), ...
                           ' ', ...
                           num2str(self.app.markerDefaults {i, 5})];
        edgeColor = (sscanf (markerColorCode, '%x').')/256;
        faceColor = 'white';

        % Specify the coordinates of the marker.
        x = self.markerTable.Data {i, 4};
        y = self.markerTable.Data {i, 5};
     
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

        handleToMarkerDrawn = line ('XData', x, 'YData', y, ...
                                    'Marker', markerShape, ...
                                    'MarkerEdgeColor', edgeColor, ...
                                    'MarkerFaceColor', faceColor, ...
                                    'Visible', visibility);
        set (handleToMarkerDrawn, ...
             'ButtonDownFcn', {@(src, event)selectMarker(self, src, event)});
        self.markersDrawn = [self.markersDrawn handleToMarkerDrawn];
      end 
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: discriminateMarker 
    %
    %  This function discriminates the marker.
    %  It returns 1 for head marker, 0 for stand alone marker, and 
    %  -1 for tail marker.
    %
    % --------------------------------------------------------------------------
    function kind = discriminateMarker (self, index)
      relatedMarkerIndex = self.app.markerDefaults {index, 6};

      if relatedMarkerIndex == 0 % Stand alond marker.
        kind = 0;

      elseif relatedMarkerIndex > index % The marker is head marker.
        kind = 1;
        
%        if self.markerTable.Data {relatedMarkerIndex, 4} ~= 0 && ...
%           self.markerTable.Data {relatedMarkerIndex, 5} ~= 0  
%           % Tail marker is already specified.
%
%          kind = 1;
%
%        else % Tail marker exists, but not specified.
%          kind = 0;
%
%        end 

      else % The marker is tail marker.
        kind = -1;

%        if self.markerTable.Data {relatedMarkerIndex, 4} ~= 0 && ...
%           self.markerTable.Data {relatedMarkerIndex, 5} ~= 0
%           % Head marker is already specified.
%
%          kind = -1;
%
%        else % Head marker exists, but not specified.
%          kind = 0;
%
%        end 
      end 
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: updateMarkerDrawn
    %
    %  This function updates marker specified and its corresponding edges.
    %
    % --------------------------------------------------------------------------
    function updateMarkerDrawn (self, index, x, y)

      markerBeingDeleted = 0;
      visibility = 'on';

      if x == 0 && y == 0 % This marker is being deactivated.
        markerBeingDeleted = 1;
        visibility = 'off';
      end 

      % Update marker shape.
      if index == self.selectedMarkerIndex 
        markerShape = 'square';
        markerFaceColor = 'none';
        markerSize = 12;

      else 
        markerSize = 6;
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

      % Update the marker with the coordinates given, shape, and visibility.
      set (self.markersDrawn (index), ...
           'Marker', markerShape, ...
           'XData', x, 'YData', y, ...
           'MarkerSize', markerSize, ...
           'MarkerFaceColor', markerFaceColor, ...
           'Visible', visibility);

      % Find and update corresponding edges.
      for i = 1 : size (self.edgeMarkerLookup, 1)

        xx = get (self.edgesDrawn (i), 'XData');
        yy = get (self.edgesDrawn (i), 'YData');

        if self.edgeMarkerLookup (i, 1) == index % Head marker is being updated.

          xx(1) = x;
          yy(1) = y;

        elseif self.edgeMarkerLookup (i, 2) == index % Tail marker is being updated.

          xx(2) = x;
          yy(2) = y;

        end 
        
        % Set line style.  If any marker is invalid, the edge will be invisible.
        lineStyle = '-';
        if xx(1) == 0 || xx(2) == 0 || yy(1) == 0 || yy(2) == 0
          lineStyle = 'none';
        end 

        set (self.edgesDrawn (i), 'XData', xx, 'YData', yy, ...
                                  'LineStyle', lineStyle);

      end 
    end 

          


    % --------------------------------------------------------------------------
    %
    %  Method: drawEdges
    %
    %  This function draws edges in accordance to the color format of markers
    %  and the connection specifications.
    %
    % --------------------------------------------------------------------------
    function drawEdges (self)
      self.edgesDrawn = [];
      self.edgeMarkerLookup = [];
      for i = 1 : size (self.app.markerDefaults, 1)
        % Examine whether a related marker is enabled.
        relatedMarkerIndex = self.app.markerDefaults {i, 6};

        if relatedMarkerIndex > i % This marker has a partner marker, with 
                                  % which defines an edge.

          % Construct edge-marker lookup table.
          self.edgeMarkerLookup = [self.edgeMarkerLookup; ...
            i relatedMarkerIndex];

          % Extract color settings for the marker.
          markerColorCode = [num2str(self.app.markerDefaults {i, 3}), ... 
                             ' ', ...
                             num2str(self.app.markerDefaults {i, 4}), ...
                             ' ', ...
                             num2str(self.app.markerDefaults {i, 5})];
          edgeColor = (sscanf (markerColorCode, '%x').')/256;

          x_head = self.markerTable.Data {i, 4};
          x_tail = self.markerTable.Data {relatedMarkerIndex, 4};

          y_head = self.markerTable.Data {i, 5};
          y_tail = self.markerTable.Data {relatedMarkerIndex, 5};

          x = [x_head x_tail];
          y = [y_head y_tail];

          % Set line style.  If any marker is invalid, the edge will be invisible.
          lineStyle = '-';
          if x_head == 0 || x_tail == 0 || y_head == 0 || y_tail == 0 || ...
             self.markerTable.Data {i, 2} == 0 || ...
             self.markerTable.Data {relatedMarkerIndex, 2} == 0

            lineStyle = 'none';
          end 

          handleToEdgeDrawn = line ('XData', x, 'YData', y, ...
                                    'LineWidth', 2, ...
                                    'LineStyle', lineStyle, ...
                                    'Color', edgeColor);, ...
          self.edgesDrawn = [self.edgesDrawn handleToEdgeDrawn];
        end 
      end 
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: selectMarker
    %
    %  This function is called when a mouse clicked on a marker.
    %
    % --------------------------------------------------------------------------
    function selectMarker (self, src, event)
      if self.selectedMarkerIndex == 0 % Selecting a marker.
        handle = gcbo;

        for i = 1 : size (self.app.markerDefaults, 1)
          if handle.XData == self.markerTable.Data {i, 4} && ...
             handle.YData == self.markerTable.Data {i, 5}  % Marker found

            self.selectedMarkerIndex = i;
            activateRow (self, i);

            % Make selected marker easy to distinguish.
            set (self.markersDrawn (self.selectedMarkerIndex), ...
                 'Marker', 'square', ...
                 'MarkerSize', 12, ...
                 'MarkerFaceColor', 'none');

            % Associate WindowButtonMotionFcn callback.
            set (self.window, ...
              'WindowButtonMotionFcn', ... 
              {@(src, event)mouseMoved(self, src, event)});
            % set (self.window, ...
              % 'WindowButtonDownFcn', ...
              % {@(src, event)relocateMarkerFinished(self, src, event)});

            break;
          end
        end

      else % Releasing the marker selected.

        % Update marker shape.
        kind = discriminateMarker (self, self.selectedMarkerIndex);

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
             'MarkerSize', 6, ...
             'MarkerFaceColor', 'white');

        % Release selected marker.
        self.selectedMarkerIndex = 0;

        set (self.window, 'WindowButtonMotionFcn', '');
        % set (self.window, 'WindowButtonDownFcn', '');

      end 
    end




    % --------------------------------------------------------------------------
    %
    %  Method: mouseMoved
    %
    %  This callback is called when a mouse moves in the movie window.
    %
    % --------------------------------------------------------------------------
    function mouseMoved (self, src, event)
      pos = get(self.imageView, 'CurrentPoint');
      
      % Get the position (x and y) of the mouse pointer.
      x = round (pos(1, 1));
      y = round (pos(1, 2));
      self.writeMarkerToRow (self.selectedMarkerIndex, x, y);

      % Update markers.
      self.updateMarkerDrawn (self.selectedMarkerIndex, x, y);

    end




    % --------------------------------------------------------------------------
    %
    %  Method: writeMarkerToRow
    %
    %  This function enters the position of mouse pointer clicked to the 
    %  row with the index given.  
    %
    % --------------------------------------------------------------------------
    function writeMarkerToRow (self, index, x, y)
      % Write the position data given.
      self.markerTable.Data {index, 4} = x;
      self.markerTable.Data {index, 5} = y;

      % Mark that the raw trajectory of the marker is editted.
      % (Re-smoothing required later.)
      marker_key = self.app.markerDefaults{index, 7};
      if self.smoothingParameters.(marker_key)(1) > 0
        self.smoothingParameters.(marker_key)(1) = ...
          -1 * self.smoothingParameters.(marker_key)(1);
      end

      self.markUnsavedChanges ();
    end




    % --------------------------------------------------------------------------
    % 
    %  Method: activateNextEnabledRow
    %
    %  This function activate the next row which is enabled.
    %  If the current active row is the last row in the table, self function
    %  sets the activeRowIndex to 0.  
    %
    % --------------------------------------------------------------------------
    function activateNextEnabledRow (self)
      % If activeRowIndex is 0, this function does nothing.
      if self.activeRowIndex == 0
        return;
      end

      % Find the next row enabled.
      for i = self.activeRowIndex + 1 : size(self.markerTable.Data, 1)
      if self.markerTable.Data {i, 2} == 1
          self.activeRowIndex = i;
          activateRow (self, i);
          return;
        end 
      end

      % There is no row enabled after the active row.
      self.activeRowIndex = 0;
      activateRow (self, 0);
    end



   
    % --------------------------------------------------------------------------
    %
    %  Method: cellEdited 
    %
    % --------------------------------------------------------------------------
    function cellEdited (self, src, event)
      % Find the index of selected row.
      selectedRow = event.Indices (1);
      selectedCol = event.Indices (2);

      if selectedCol == 2 % Checkbox is clicked.
                          % Enable or disable the selected row accordingly.

        if src.Data{selectedRow, 2} == 0  % The selected row is being disabled.
          % Disable the row setting the coordinates of the marker to 0.
          if self.movieFileName ~= 0
            writeMarkerToRow (self, selectedRow, 0, 0);
            updateMarkerDrawn (self, selectedRow, 0, 0);
          end
          selectedRow = 0;

        else % The selected row is being enabled.
          activateRow (self, selectedRow);

        end 
      end 
    end 




    % --------------------------------------------------------------------------
    %
    %  Method: cellSelected
    %
    %  This callback function is called when a cell is selected in the uitable
    %  which shows the markers.
    %
    % --------------------------------------------------------------------------
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
          activateRow (self, selectedRow);
        end 
      end 
    end




    % --------------------------------------------------------------------------
    %
    %  Method: clearViewCallback
    %
    %  This callback function is called when clearViewCheckbox is clicked.
    %
    % --------------------------------------------------------------------------
    function clearViewCallback(self, src, event)
      loadAndDisplayImage (self);
    end
    
    
    
   
  end
  
end
