include <BOSL/threading.scad>
$fn=60;

render_for_print = false;
render_stem = true;
render_connection_block_maestro = true;
explosion_distance = 20;

// Sections from bottom to top
// each vector element is a vector of:
// 0: zOffset of the section
// 1: height of the section
// 2: d1 - diameter of the bottom of the section
// 3: d2 - diameter of the top of the section
// 4: domed - whether there is a domed top to the section
sections = [
    [0, 40, 45, 45, false],
    [40, 23, 23, 23, false],
    [63, 20, 26, 24, false],
    [83, 24, 20, 19, false],
    [107, 20, 24, 23, false],
    [127, 10, 17, 15, false],
    [137, 32, 22, 20, true],
];

// z locations of side holes, from bottom to top
side_holes = [
    25,
    50,
    95,
    132
];

// Diameter of the side holes
side_hole_diameter = 5.2;

// Size of the connection block
connection_block_size = [27, 27, 30];

// additional space to leave above the connection block in the stem
connection_block_clearance_above = 1;

// additional space to leave around the connection block in the stem
connection_block_clearance_around = 0.5;

// We render slightly differently depending on the rendering mode
if (render_for_print) {
    if (render_stem == true) {
        stem_offset_x = (sections[len(sections) - 1][0] + sections[len(sections) - 1][1]) / 2;
        stem_offset_y = (sections[0][0] + sections[0][1]) / 2;
        
        translate([-stem_offset_x, -stem_offset_y]) rotate([0, 90, 0]) half_stem();
        translate([stem_offset_x, stem_offset_y]) rotate([0, 90, 180]) half_stem();
    }
    
    if (render_connection_block_maestro == true) {
        if (render_stem == true) {
            // don't overlap with the stem halves!
            connection_block_offset_y = (sections[0][0] + sections[0][1]) + connection_block_size[1];
            translate([0, connection_block_offset_y]) connection_block_maestro();
        } else {
            connection_block_maestro();
        }
    }
} else {
    // preview layout
    if (render_stem == true) {
        
        // Left stem
        translate([-explosion_distance, 0, 0]) half_stem();
        
        // Right Stem
        translate([explosion_distance, 0, 0]) rotate([0, 0, 180]) half_stem();
    }
    
    if (render_connection_block_maestro == true) { 
        translate([0, 0, -explosion_distance]) connection_block_maestro(); 
    }
}

//
// Renders half a stem for printing
//
module half_stem() {
    difference() {
        stem();
        translate([0, -100, 0]) cube([200, 200, 500]);
    }
}

//
// Renders the stem, with holes drilled through
//
module stem()
{
    difference() {        
        
        // render each section
        union() {
            for (section = sections) {        
                translate([0, 0, section[0]]) stem_section(section);
            }
        }
        
        // drill out side shafts
        side_shafts();
        
        // remove connection block void
        block_void_x_size = connection_block_size[0] + (2 * connection_block_clearance_around);
        block_void_y_size = connection_block_size[1] + (2 * connection_block_clearance_around);
        rotate([0, 0, 45]) { // we rotate the void so when printed, everything sits nicely
            translate([-(block_void_x_size / 2), -(block_void_y_size / 2)]) {
                cube([
                    block_void_x_size, // x
                    block_void_y_size, // y
                    connection_block_size[0] + (2 * connection_block_clearance_above) // z
                ]);
            }
        }
    }
}

//
// Renders the specified stem section
//
module stem_section(section) {
    if (section[4] == true) {
        union() {
            cylinder(h=section[1]-(section[3] / 2), d1=section[2], d2=section[3]);
            translate([0, 0, section[1]-(section[3] / 2)]) sphere(d=section[3]);
        }
    } else {
        cylinder(h=section[1], d1=section[2], d2=section[3]);
    }
}

//
// Renders the shafts used to drill the side holes
//
module side_shafts() {
    for (hole_z = side_holes) {
        translate([0, 0, hole_z]) rotate([0, 90, 0]) cylinder(h=100, d=side_hole_diameter, center=true);
    }
}

//
// Renders a connection block for the Maestro fucking machine
//
module connection_block_maestro() {
    
    difference() {
        rotate([0, 0, 45]) { // as above, the connection block is rotated 45 degrees
            union() {
                difference() {
                    // the block itself
                    translate([-(connection_block_size[0] / 2), -(connection_block_size[1] / 2)]) cube(connection_block_size);
                    
                    // void we'll fill with the thread
                    cylinder(h=30, d=20);
                }
                
                // Threaded nut to connect to the machine shaft
                metric_trapezoidal_threaded_nut(od=23, id=17, h=30, pitch=2, bevel=true, align=V_TOP);
            }
        }
        
        // remove any side shaft intersections
        side_shafts();
    }
}