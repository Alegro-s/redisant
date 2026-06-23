package io.mateshell;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import java.util.List;

public class DesktopAdapter extends RecyclerView.Adapter<DesktopAdapter.VH> {

    interface Listener {
        void onClick(DesktopIcon icon);
    }

    private final List<DesktopIcon> items;
    private final Listener listener;

    DesktopAdapter(List<DesktopIcon> items, Listener listener) {
        this.items = items;
        this.listener = listener;
    }

    @NonNull
    @Override
    public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_desktop_icon, parent, false);
        return new VH(v);
    }

    @Override
    public void onBindViewHolder(@NonNull VH h, int position) {
        DesktopIcon icon = items.get(position);
        h.emoji.setText(icon.emoji);
        h.label.setText(icon.label);
        h.itemView.setOnClickListener(v -> listener.onClick(icon));
    }

    @Override
    public int getItemCount() {
        return items.size();
    }

    static class VH extends RecyclerView.ViewHolder {
        TextView emoji, label;
        VH(View v) {
            super(v);
            emoji = v.findViewById(R.id.iconEmoji);
            label = v.findViewById(R.id.iconLabel);
        }
    }
}
