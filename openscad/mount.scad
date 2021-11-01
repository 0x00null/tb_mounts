include <BOSL/threading.scad>
$fn=60;

stem_type = "none";
connection_block_type = "none";

render_for_print = true;
explosion_distance = 20;

// Sections go from bottom to top
// each vector element is a vector of:
// 0: zOffset of the section
// 1: height of the section
// 2: d1 - diameter of the bottom of the section
// 3: d2 - diameter of the top of the section
// 4: domed - whether there is a domed top to the section
stem_types = [
    [
        "tb_large",
        [
            [0, 40, 45, 45, false], // base for connection block
            [40, 23, 23, 23, false],
            [63, 20, 26, 24, false],
            [83, 24, 20, 19, false],
            [107, 20, 24, 23, false],
            [127, 10, 17, 15, false],
            [137, 32, 22, 20, true],
        ]
    ],
    [
        "vac-u-lock",
        [
            [0, 40, 45, 45, false], // base for connection block
            [40, 25.62, 20.32, 20.32, false],
            [65.62, 20.32, 25.4, 21.59, false],
            [85.94, 36.2, 27.43, 21.59, true]
        ]
    ]
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
if (render_for_print == true) {
    
    // In print layout, we render the stem in two halves, face down on the bed
    if (stem_type != "none") {
        
        // we need to arrange the stem pieces nicely
        // Find the stem to render, then pass its sections to the render_sections module
        for(t = stem_types) {
            if (t[0] == stem_type) { // t[0] is the string name of the stem type
                
                // stem offsets are used to arrange the stems
                // t[1] is the vector of sections
                // t[1][0] is the mottom most section
                // t[1][0][0] is the z offset of the bottommost section
                
                // offset_x is based on the overall height of the stem
                // offset_y is based on the width of the first section (as it's the widest!)
        
                // zOffset of the topmost section, plus it's height
                stem_offset_x = (t[1][len(t[1]) - 1][0] + t[1][len(t[1]) - 1][1]) / 2;        
                
                // width of the bottommost section
                stem_offset_y = (t[1][0][2]) / 2;
                
                translate([-stem_offset_x, -stem_offset_y]) rotate([0, 90, 0]) half_stem();
                translate([stem_offset_x, stem_offset_y]) rotate([0, 90, 180]) half_stem();
            }
        }
        
        
    }
    
    if (connection_block_type != "none") {
        if (stem_type != "none") {
            // don't overlap with the stem halves!
            // Take the first diameter of the first section of the first type of stem as a rough guess
            connection_block_offset_y = (stem_types[0][1][0][2]) + connection_block_size[1];
            translate([0, connection_block_offset_y]) connection_block();
        } else {
            connection_block();
        }
    }
    
} else {
    
    if (stem_type != "none") {
        // Left half-stem
        translate([-explosion_distance, 0, 0]) half_stem();
        
        // Right half-stem
        translate([explosion_distance, 0, 0]) rotate([0, 0, 180]) half_stem();
    }
    if (connection_block_type != "none") { 
        translate([0, 0, -explosion_distance]) connection_block(); 
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
        
        // Find the stem to render, then pass its sections to the render_sections module
        for(t = stem_types) {
            if (t[0] == stem_type) { // t[0] is the string name of the stem type
                stem_sections(t[1]); // t[1] is the section vector for this stem type
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

module stem_sections(sections) {
    union() {
        for (section = sections) {      
            translate([0, 0, section[0]]) stem_section(section);
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
// Renders the appropiate module based on the specified type
// Wouldn't it be nice if we could hold a pointer to a module in a vector... then we'd not have to do this nonsense!
//
module connection_block() {
            if (connection_block_type == "maestro") { connection_block_maestro(); }
            if (connection_block_type == "knuckles") { connection_block_knuckles(); }
}



//
// Renders a connection block for the Maestro fucking machine
//
module connection_block_maestro() {
    difference() {
        rotate([0, 0, 45]) union() { // rotate 45 for the side shaft to drill through properly
            difference() {
                // the block itself
                translate([-(connection_block_size[0] / 2), -(connection_block_size[1] / 2)]) cube(connection_block_size);
                
                // void we'll fill with the thread
                cylinder(h=30, d=20);
            }
            
            // Threaded nut to connect to the machine shaft
            metric_trapezoidal_threaded_nut(od=23, id=17, h=30, pitch=2, bevel=true, align=V_TOP);
        }
        
        side_shafts();
    
    }
}

//
// Renders a connection block for brass knuckles
//
module connection_block_knuckles() {   
    if (render_for_print == true) {
        translate([0, 45, connection_block_size[2] / 2]) rotate([0, 90, 0]) rotate([0, 0, 45]) connection_block_knuckles_core();
    } else {
        connection_block_knuckles_core();
    }
    
}

//
// Renders the core knuckles connector in 'preview' orientation
//
module connection_block_knuckles_core() {
    difference() {
        rotate([0, 0, 45]) union() { // rotate for the side shafts to drill properly
            translate([0, (connection_block_size[1] / 2), -(27.5 + 15)]) rotate([90, 0, 0]) union() {
                // Stack the knuckles to be the same depth as the connector block
                // the model is a little...wonky
                connection_block_knuckles_import();
                translate([0, 0, connection_block_size[2] - 22.9744]) connection_block_knuckles_import();
            }
            
            // the block itself
            translate([-(connection_block_size[0] / 2), -(connection_block_size[1] / 2), -15]) cube([connection_block_size[0], connection_block_size[1], connection_block_size[2] + 15]);
        }
        side_shafts();
    }
}

//
// Renders the resized knuckles model
//
module connection_block_knuckles_import() {
    render() intersection() {
        translate([0, 0, 12.01]) import("./assets/knuckles/files/bower.stl");
        translate([-150, -150, 0]) cube([300, 300, 20]);
    }
}