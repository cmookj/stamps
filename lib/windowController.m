classdef windowController < handle

properties
  window
end


methods
  function self = windowController ()
    self.window = [];
  end

  %%
  %  createWindow
  %
  %  This method creates a new window with the width and height given.
  %
  function createWindow (self, width, height)
    self.window = figure ( ...
      'NumberTitle', 'off', ...
      'Visible', 'off', ...
      'Position', [0 0 width height], ...
      'CloseRequestFcn', @(src, event)closeWindowCallback (self, src, event), ...
      'SizeChangedFcn', @(src, event)resizeWindowCallback (self, src, event));
  end


  %%
  %  showWindow
  %
  %  This method shows the window.
  %
  function showWindow (self)

    if isempty (self.window)
      self.createWindow ();
    end

    % Make the window current figure.
    set (self.window, 'Visible', 'on');
    figure (self.window);

  end


  %%
  %  setWindowTitle
  %
  %  This method sets the title of the window.
  %
  function setWindowTitle (self, title)
    if ~isempty (self.window)
      set (self.window, 'Name', title);
    end
  end


  %%
  %  maximizeWindow
  %
  %  This method maximizes the window to full-screen size.
  %
  function maximizeWindow (self)
    if ~isempty (self.window)
      % Obtain the size of the screen
      % scrsz = get(groot,'ScreenSize');
      % screenWidth = scrsz(3);
      % screenHeight = scrsz(4);

      % position = self.window.Position(1:2);

      set (self.window, 'WindowState', 'maximized');

      self.layoutWindow ();
    end
  end


  %%
  %  closeWindowCallback
  %
  %  This function is by a close request.
  %
  function answer = closeWindowCallback (self, src, event)
    answer = true;
    self.closeWindow ();
  end


  %%
  %  enableResize
  %
  %  This function enables resizing of the window.
  %
  function enableResize (self)
    if ~isempty (self.window)
      set (self.window, 'Resize', 'on');
    end
  end


  %%
  %  disableResize
  %
  %  This function disables resizing of the window.
  %
  function disableResize (self)
    if ~isempty (self.window)
      set (self.window, 'Resize', 'off');
    end
  end


  %%
  %  resizeWindowCallback
  %
  %  This function is called when the size of the window changes.
  %
  function resizeWindowCallback (self, src, event)
    self.resizeWindow ();
  end


  %%
  %  closeWindow
  %
  %  This function closes the window.
  %
  function closeWindow (self)
    if ~isempty (self.window)
      delete (self.window);
      self.window = [];
    end
  end


  %%
  %  resizeWindow
  %
  %  This function re-calculate the layout of the window.
  %
  function resizeWindow (self)
    self.layoutWindow ();
  end


  %%
  %  terminate
  %
  %  This function closes the window finalizing the execution of the window controller.
  %
  function terminate (self)
    if ~isempty (self.window)
      delete (self.window);
      self.window = [];
    end
  end


end


methods (Access = protected)
  %%
  %  layoutWindow
  %
  %  This function lays views and controls in accordance to the window size.
  %
  function layoutWindow (self)
    % Do nothing yet.  Subclasses should override this.
  end

end

end
