
// Slider + textfield
void tfslider (T)(uint* id, ref T value, T minValue, T maxValue) {
    ui.horizontal({
        ui.textfield(id, value); value.clamp(minValue, maxValue);
        ui.slider(null, value, minValue, maxValue);
    });
}

void colorSlider (
    ImuiContext ui,
    ref uint[] ids,
    ref vec4 colorRgba,
    vec4 function(vec4) toRgba,
    vec4 function(vec4) fromRgba,
    vec4 min, vec4 max
) {
    auto color = fromRgba(colorRgba);
    ui.vertical({
        ui.tfslider(&ids[0], color.x, min.x, max.x);
        ui.tfslider(&ids[1], color.y, min.y, max.y);
        ui.tfslider(&ids[2], color.z, min.z, max.z);
        ui.tfslider(&ids[3], color.w, min.w, max.w);
    });
    colorRgba = fromRgba(color);
}

class ColorDemo {
    vec4     color;
    uint     frameId;
    uint[4]  panelIds;
    uint[16] sliderIds;

    this (ModuleSandbox sb) {
        auto ui = sb.ui;
        ui.frame(&frameId, "color demo", {
            ui.horizontal({
                // Info
                ui.vertical({
                    ui.rect(null, vec2i(100, 100), SColor(color));
                    ui.label(null, format("rgb: %s", color.formatVec));
                    ui.label(null, format("hsl: %s", color.rgbaToHusl.formatVec));
                    ui.label(null, format("XYZ: %s", color.rgbaToXYZ.formatVec));
                });
                
                // Sliders
                ui.table([[{
                    ui.panel(&panelIds[0], "rgba", {
                        ui.colorSlider(sliderIds[4..8], color, &vec4_identity, &vec4_identity, vec4(0,0,0,0), vec4(1,1,1,1));
                    });
                }, {
                    ui.panel(&panelIds[1], "husl", {
                        ui.colorSlider(sliderIds[8..12], color, &rgbaToHusl, &huslToRgba, vec4(0,0,0,0), vec4(360,100,100,100));
                    });
                }], [{
                    ui.panel(&panelIds[2], "hsl", {
                        ui.colorSlider(sliderIds[12..16], color, &rgbaToHsl, &hslToRgba, vec4(0,0,0,0), vec4(1,1,1,1));
                    });
                }, {
                    ui.panel(&panelIds[3], "XYZ", {
                        ui.colorSlider(sliderIds[16..24], color, &rgbaToXYZ, &XYZToRgba, vec4(0,0,0,0), vec4(1,1,1,1)));
                    });
                }]]); 
            });  
        });
    }
}








 


















































