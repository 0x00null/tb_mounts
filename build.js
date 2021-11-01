'use strict';
const log = require('npmlog');

const fs = require('fs');
const commandExists = require('command-exists');
const execa = require('execa');

async function run(args) {
    log.info('SETUP', 'Setting up for build...');

    // Check openscad is on the path
    if ((await commandExists('openscad'))) {
        log.info('SETUP', '✔ Found OpenSCAD on your path');
    } else {
        log.error('SETUP', '❌ OpenSCAD was not found on your path. Is OpenSCAD installed?');
        return -1;
    }

    // Fetch BOSL?
    let boslDirStats = null;
    try {
        boslDirStats = await fs.promises.stat('openscad/BOSL');
    } catch { }

    try
    {
        if (boslDirStats != null && boslDirStats.isDirectory()) {
            // Clean up the old BOSL checkout
            log.info('SETUP', '🧹 Cleaning previous BOSL pull...');
            await fs.promises.rmdir('openscad/BOSL', { recursive: true, foce: true });
            log.info('SETUP', `✔ BOSL clean complete`);
        }
    } catch (ex) {
        log.error('SETUP', '❌ Failed to clean BOSL');
        log.error('SETUP', ex.message);
        return -1;
    }

    log.info('SETUP', '⏳ Pulling Belfry OpenSCAD library...');
    try {
        await execa('git', ['clone', 'https://github.com/revarbat/BOSL.git', 'openscad/BOSL']);
    } catch (ex) {
        log.error('SETUP', '❌ Failed to clone BOSL');
        log.error('SETUP', ex.message);
        return -1;
    }
    log.info('SETUP', `✔ Pulled Belfry OpenSCAD library`);

    // Load the build config
    let config = null;
    try
    {
        config = JSON.parse(await fs.promises.readFile('./build-config.json'));
    } catch (ex) {
        log.error('SETUP', '❌ Failed to load build-config.json');
        log.error('SETUP', ex.message);
        return -1;
    }

    log.info('SETUP', `✔ Loaded ${config.stems.length} stem and ${config.connection_blocks.length} connector block configurations`);


    // Generate the customser file
    let customiser = {
        parameterSets : { },
        fileFormatVersion : '1'
    };

    // Add each stem type
    for (const stemType of config.stems) {
        customiser.parameterSets[`stem_${stemType.name}`] = {
            stem_type : stemType.name
        }
    };

    // Add each connection block type
    for (const blockType of config.connection_blocks) {
        customiser.parameterSets[`block_${blockType.name}`] = {
            connection_block_type : blockType.name
        }
    };


    try {
        await fs.promises.writeFile('openscad/customiser.json', JSON.stringify(customiser));
    } catch (ex) {
        log.error('SETUP', '❌ Failed to write customiser.json');
        log.error('SETUP', ex.message);
        return -1;
    }

    log.info('SETUP', '✔ Generated OpenSCAD customiser file');

    // Prepare the output folder
    const outputBasePath = `${__dirname}/output`;
    const stemOutputBasePath = `${outputBasePath}/stems`;
    const blockOutputBasePath = `${outputBasePath}/connection_blocks`;
    
    let outDirStats = null;
    try
    {
        outDirStats = (await fs.promises.stat(outputBasePath));
    } catch { }

    try {
        if (outDirStats != null && outDirStats.isDirectory()) {
            // Clean up the old output dir
            log.info('SETUP', '🧹 Cleaning output folder...');
            await fs.promises.rmdir(outputBasePath, { recursive: true, foce: true });
            log.info('SETUP', `✔ Output folder cleaned`);
        }
    } catch (ex) {
        log.error('SETUP', '❌ Failed to clean output folder');
        log.error('SETUP', ex.message);
        return -1;
    }

    // Create output paths
    await fs.promises.mkdir(outputBasePath);
    await fs.promises.mkdir(stemOutputBasePath);
    await fs.promises.mkdir(blockOutputBasePath);

    // Create the customiser file used to render each component
    let hasErrors = false;
    const customiserPath = `${__dirname}/openscad/customiser.json`;
    const scadFilePath = `${__dirname}/openscad/mount.scad`;
    

    // Render each stem
    for (const stemType of config.stems) {
        
        const outPath = `${stemOutputBasePath}/${stemType.name}.stl`;
        
        log.info('RENDER', `🌻 Rendering stem '${stemType.name}' to ${outPath}...`);
        if (stemType.licence !== undefined && stemType.licence !== null) {
            log.info('RENDER', `  ❤ ${stemType.licence}`);
        }
        // log.info(`openscad -p ${customiserPath} -P stem_${stemType} -o ${outPath} ${scadFilePath}`);

        try {
        await execa('openscad', [
            '-p', customiserPath, 
            '-P', `stem_${stemType.name}`,
            '-o', outPath,
            scadFilePath]);
        } catch (ex) {
            hasErrors = true;
            log.warn('RENDER', `⚠ Failed to render stem ${stemType}`);
            log.warn('RENDER', ex.message);
        }
    }


    for (const blockType of config.connection_blocks) {
        
        const outPath = `${blockOutputBasePath}/${blockType.name}.stl`;
        
        log.info('RENDER', `🧊 Rendering connection block '${blockType.name}' to ${outPath}...`);
        if (blockType.licence !== undefined && blockType.licence !== null) {
            log.info('RENDER', `  ❤  ${blockType.licence}`);
        }

        try {
        await execa('openscad', [
            '-p', customiserPath, 
            '-P', `block_${blockType.name}`,
            '-o', outPath,
            scadFilePath]);
        } catch (ex) {
            hasErrors = true;
            log.warn('RENDER', `⚠ Failed to render block ${blockType}`);
            log.warn('RENDER', ex.message);
        }
    }


    if (hasErrors == true) {
        log.error('RENDER', '❌ One or more renders failed');
        return -1;
    }

    // we're done!
    log.info('FINISHED', '🥳 Components rendered. Finished!');
}


(async () => {
    try {
        await run();
    } catch (e) {
        // Deal with the fact the chain failed
    }
})();