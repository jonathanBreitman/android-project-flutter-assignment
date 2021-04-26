DRY ANSWERS:
1. the class that is used to implement the controller pattern in this library is SnappingSheetController.
    It allows the developer to get information about the snapping sheet (like its position, or whether it is
    currently snapping), and also control things like snapping it to  specific position, stop current snapping,
     and set the snapping factor and the widget's position.

2. the parameter that controls the animation is SnappingPositions.

3. InkWell's advantage over GestureDetector is that it has the ripple animation effect, and GestureDetector's
    advantage over InkWell is that it provides a bit more control options, like dragging.