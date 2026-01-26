function bringToFront(event, allLines)
    % Reset all lines
    set(allLines, 'LineWidth', 0.5);

    % Selected line
    hLine = event.Peer;

    % Bring to top
    uistack(hLine, 'top');

    % Highlight
    hLine.LineWidth = 0.5;
end