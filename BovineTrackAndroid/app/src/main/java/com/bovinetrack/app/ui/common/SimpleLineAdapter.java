package com.bovinetrack.app.ui.common;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.bovinetrack.app.R;

import java.util.ArrayList;
import java.util.List;

public class SimpleLineAdapter extends RecyclerView.Adapter<SimpleLineAdapter.Holder> {
    private final List<Item> items = new ArrayList<>();

    public void submit(List<Item> incoming) {
        items.clear();
        items.addAll(incoming);
        notifyDataSetChanged();
    }

    @NonNull
    @Override
    public Holder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_simple_line, parent, false);
        return new Holder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull Holder holder, int position) {
        Item item = items.get(position);
        holder.title.setText(item.title);
        holder.subtitle.setText(item.subtitle);
        holder.itemView.setContentDescription(item.title + ". " + item.subtitle);
    }

    @Override
    public int getItemCount() {
        return items.size();
    }

    public static class Item {
        public final String title;
        public final String subtitle;

        public Item(String title, String subtitle) {
            this.title = title;
            this.subtitle = subtitle;
        }
    }

    static class Holder extends RecyclerView.ViewHolder {
        TextView title;
        TextView subtitle;

        Holder(@NonNull View itemView) {
            super(itemView);
            title = itemView.findViewById(R.id.title);
            subtitle = itemView.findViewById(R.id.subtitle);
        }
    }
}
