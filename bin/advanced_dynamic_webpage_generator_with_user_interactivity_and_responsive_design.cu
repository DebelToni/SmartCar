/*
 * This JavaScript code creates a dynamic, responsive webpage that allows users to add, remove, and customize content blocks.
 * Features include drag-and-drop reordering, color customization, and real-time layout adjustments.
 * Designed for modularity and scalability, suitable for a dashboard or customizable interface.
 */

// Immediately Invoked Function Expression to avoid polluting global namespace
(function() {
    // Cache DOM elements
    const container = document.createElement('div');
    container.id = 'content-container';
    container.style.display = 'flex';
    container.style.flexDirection = 'column';
    container.style.margin = '20px';
    container.style.gap = '10px';
    document.body.appendChild(container);

    const controlPanel = document.createElement('div');
    controlPanel.id = 'control-panel';
    controlPanel.style.display = 'flex';
    controlPanel.style.flexWrap = 'wrap';
    controlPanel.style.gap = '10px';
    controlPanel.style.marginBottom = '20px';
    document.body.insertBefore(controlPanel, container);

    // Utility function to create buttons
    function createButton(text, onClick) {
        const btn = document.createElement('button');
        btn.innerText = text;
        btn.style.padding = '8px 12px';
        btn.style.cursor = 'pointer';
        btn.onclick = onClick;
        return btn;
    }

    // Initialize control buttons
    const addBlockBtn = createButton('Add Content Block', () => addContentBlock());
    const clearAllBtn = createButton('Clear All', () => clearAllBlocks());
    controlPanel.appendChild(addBlockBtn);
    controlPanel.appendChild(clearAllBtn);

    // Counter for unique IDs
    let blockCounter = 0;

    // Function to add a new content block
    function addContentBlock() {
        blockCounter++;
        const blockId = `block-${blockCounter}`;

        const block = document.createElement('div');
        block.className = 'content-block';
        block.draggable = true;
        block.id = blockId;
        block.style.border = '1px solid #ccc';
        block.style.borderRadius = '4px';
        block.style.padding = '10px';
        block.style.backgroundColor = '#f9f9f9';
        block.style.display = 'flex';
        block.style.flexDirection = 'column';
        block.style.position = 'relative';
        block.style.cursor = 'move';

        // Content area
        const contentArea = document.createElement('div');
        contentArea.innerHTML = `<p>Content Block ${blockCounter}</p>`;
        contentArea.style.flexGrow = '1';
        contentArea.style.marginBottom = '10px';
        block.appendChild(contentArea);

        // Control buttons for each block
        const controlsDiv = document.createElement('div');
        controlsDiv.style.display = 'flex';
        controlsDiv.style.justifyContent = 'space-between';

        // Remove button
        const removeBtn = createButton('Remove', () => {
            container.removeChild(block);
        });
        removeBtn.style.flex = '1';
        removeBtn.style.marginRight = '5px';

        // Color picker
        const colorInput = document.createElement('input');
        colorInput.type = 'color';
        colorInput.value = '#f9f9f9';
        colorInput.title = 'Change Background Color';
        colorInput.style.flex = '1';
        colorInput.style.marginRight = '5px';
        colorInput.onchange = () => {
            block.style.backgroundColor = colorInput.value;
        };

        // Drag handle
        const dragHandle = document.createElement('div');
        dragHandle.innerHTML = '&#9776;'; // Hamburger icon
        dragHandle.title = 'Drag to Reorder';
        dragHandle.style.cursor = 'grab';
        dragHandle.style.fontSize = '20px';
        dragHandle.style.flex = '0 0 auto';

        // Append controls
        controlsDiv.appendChild(dragHandle);
        controlsDiv.appendChild(removeBtn);
        controlsDiv.appendChild(colorInput);
        block.appendChild(controlsDiv);

        // Append block to container
        container.appendChild(block);

        // Attach drag events for reordering
        attachDragEvents(block);
    }

    // Function to clear all blocks
    function clearAllBlocks() {
        while (container.firstChild) {
            container.removeChild(container.firstChild);
        }
    }

    // Drag and Drop Functionality
    let dragSrcEl = null;

    function handleDragStart(e) {
        this.style.opacity = '0.4';
        dragSrcEl = this;
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', this.id);
    }

    function handleDragOver(e) {
        if (e.preventDefault) {
            e.preventDefault();
        }
        e.dataTransfer.dropEffect = 'move';
        return false;
    }

    function handleDragEnter() {
        this.style.border = '2px dashed #000';
    }

    function handleDragLeave() {
        this.style.border = '1px solid #ccc';
    }

    function handleDrop(e) {
        if (e.stopPropagation) {
            e.stopPropagation();
        }
        if (dragSrcEl !== this) {
            // Swap the nodes
            const nodes = Array.from(container.children);
            const srcIndex = nodes.indexOf(dragSrcEl);
            const targetIndex = nodes.indexOf(this);
            if (srcIndex < targetIndex) {
                container.insertBefore(dragSrcEl, this.nextSibling);
            } else {
                container.insertBefore(dragSrcEl, this);
            }
        }
        return false;
    }

    function handleDragEnd() {
        this.style.opacity = '1';
        Array.from(container.children).forEach((child) => {
            child.style.border = '1px solid #ccc';
        });
    }

    // Attach drag events to a block
    function attachDragEvents(element) {
        element.addEventListener('dragstart', handleDragStart, false);
        element.addEventListener('dragover', handleDragOver, false);
        element.addEventListener('dragenter', handleDragEnter, false);
        element.addEventListener('dragleave', handleDragLeave, false);
        element.addEventListener('drop', handleDrop, false);
        element.addEventListener('dragend', handleDragEnd, false);
        // Optional: change cursor on drag handle
        const dragHandle = element.querySelector('div[title="Drag to Reorder"]');
        if (dragHandle) {
            dragHandle.style.cursor = 'grab';
            dragHandle.onmousedown = () => {
                document.body.style.cursor = 'grabbing';
            };
            document.body.onmouseup = () => {
                document.body.style.cursor = 'default';
            };
        }
    }

    // Initialize by adding a few default blocks
    for (let i = 0; i < 3; i++) {
        addContentBlock();
    }
})();